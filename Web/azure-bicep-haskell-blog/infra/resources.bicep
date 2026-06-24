@description('모든 리소스의 위치')
param location string

@description('리소스 이름을 전역 고유하게 만드는 토큰')
param resourceToken string

@description('모든 리소스에 적용할 태그')
param tags object

@description('PostgreSQL 관리자 로그인 이름')
param postgresAdminLogin string

@secure()
@description('PostgreSQL 관리자 비밀번호')
param postgresAdminPassword string

@description('개발자가 PostgreSQL 에 직접 접속하도록 허용할 공인 IP. 비우면 방화벽에 개발자 규칙을 만들지 않는다(앱만 접근). dev 환경에서만 설정 권장.')
param developerIpAddress string = ''

@description('PostgreSQL 에 Microsoft Entra 관리자로 등록할 주체의 objectId. 비우면 Entra 관리자를 만들지 않는다(비밀번호 인증만).')
param entraAdminObjectId string = ''

@description('Entra 관리자 주체의 표시 이름(UPN/이메일 또는 그룹명). psql 접속 시 user 로 사용한다.')
param entraAdminPrincipalName string = ''

@allowed([ 'User', 'Group', 'ServicePrincipal' ])
@description('Entra 관리자 주체 유형.')
param entraAdminPrincipalType string = 'User'

@description('배포할 컨테이너 이미지. azd deploy가 실제 이미지를 푸시하기 전까지 사용하는 플레이스홀더.')
param webImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('ACS(이메일) 데이터 저장 위치(데이터 레지던시). 예: United States, Europe, Asia Pacific, Australia, UK.')
param acsDataLocation string = 'United States'

@secure()
@description('서명 마스터 키(PREVIEW_SECRET). main.bicep 이 azd 환경의 고정값을 전달한다. (모듈을 단독 배포할 때만 newGuid() 폴백이 동작하며, 그 경우 배포마다 값이 바뀜에 유의.)')
param previewSecret string = newGuid()

var databaseName = 'blog'

// ---------- Log Analytics (ACA 환경 로그) ----------
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'log-${resourceToken}'
  location: location
  tags: tags
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

// ---------- 사용자 할당 매니지드 ID (ACR Pull용) ----------
resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-${resourceToken}'
  location: location
  tags: tags
}

// ---------- Azure Container Registry ----------
resource registry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: 'cr${resourceToken}'
  location: location
  tags: tags
  sku: { name: 'Basic' }
  properties: {
    adminUserEnabled: false
  }
}

// 매니지드 ID에 AcrPull 권한 부여
resource acrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(registry.id, identity.id, 'AcrPull')
  scope: registry
  properties: {
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
    // AcrPull 역할 정의 ID
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
  }
}

// ---------- PostgreSQL Flexible Server (Burstable B1ms, 공용 접근 + IP 허용) ----------
// 개발 환경: 공용 엔드포인트를 켜되 방화벽으로 접근을 좁힌다.
// - 앱(ACA)은 'Allow Azure services' 규칙으로 도달(0.0.0.0 특수 규칙).
// - 개발자는 developerIpAddress 단일 IP 규칙으로만 도달.
// - 전송은 sslmode=require(TLS) 강제, 인증은 비밀번호 + Microsoft Entra 병행.
// 운영에서 노출을 더 줄이려면 publicNetworkAccess:Disabled + Private Endpoint 로 전환.
resource postgres 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' = {
  name: 'psql-${resourceToken}'
  location: location
  tags: tags
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  properties: {
    version: '16'
    administratorLogin: postgresAdminLogin
    administratorLoginPassword: postgresAdminPassword
    storage: { storageSizeGB: 32 }
    backup: { backupRetentionDays: 7, geoRedundantBackup: 'Disabled' }
    highAvailability: { mode: 'Disabled' }
    network: { publicNetworkAccess: 'Enabled' }
    // 비밀번호 인증(앱의 DATABASE_URL)과 Entra 인증(개발자)을 함께 허용.
    authConfig: {
      activeDirectoryAuth: 'Enabled'
      passwordAuth: 'Enabled'
      tenantId: subscription().tenantId
    }
  }
}

resource postgresDb 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2024-08-01' = {
  parent: postgres
  name: databaseName
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

// Azure 내부 서비스(Container Apps 포함) 접근 허용 (0.0.0.0 = Allow Azure services).
// 앱이 공용 엔드포인트로 DB 에 도달하기 위한 최소 규칙.
resource allowAzure 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2024-08-01' = {
  parent: postgres
  name: 'AllowAllAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// 개발자 단일 IP 허용(설정된 경우에만). dev 환경에서 azd env set 으로 주입.
resource allowDeveloper 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2024-08-01' = if (!empty(developerIpAddress)) {
  parent: postgres
  name: 'AllowDeveloper'
  properties: {
    startIpAddress: developerIpAddress
    endIpAddress: developerIpAddress
  }
}

// PostgreSQL Microsoft Entra 관리자(설정된 경우에만).
// 개발자는 az login 토큰을 비밀번호로 써서 이 주체로 접속한다(공유 admin 비밀번호 불필요).
resource pgEntraAdmin 'Microsoft.DBforPostgreSQL/flexibleServers/administrators@2024-08-01' = if (!empty(entraAdminObjectId)) {
  parent: postgres
  name: entraAdminObjectId
  properties: {
    principalType: entraAdminPrincipalType
    principalName: entraAdminPrincipalName
    tenantId: subscription().tenantId
  }
  dependsOn: [ postgresDb ]
}

// ---------- Container Apps 환경 (Consumption 전용) ----------
// 공용 Postgres 엔드포인트로 도달하므로 VNet 통합은 두지 않는다(기본 egress 사용).
resource containerEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: 'cae-${resourceToken}'
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

// DATABASE_URL 연결 문자열 (Flexible Server는 sslmode=require 필수)
var databaseUrl = 'postgresql://${postgresAdminLogin}:${postgresAdminPassword}@${postgres.properties.fullyQualifiedDomainName}:5432/${databaseName}?sslmode=require'

// ---------- Azure Communication Services Email ----------
// 가입 인증 6자리 코드를 실제 이메일로 발송한다. Azure 관리형 도메인(AzureManaged)을
// 써서 DNS 인증 없이 배포 즉시 donotreply@<생성도메인>.azurecomm.net 으로 보낼 수 있다.
resource emailService 'Microsoft.Communication/emailServices@2023-04-01' = {
  name: 'acs-email-${resourceToken}'
  location: 'global'
  tags: tags
  properties: {
    dataLocation: acsDataLocation
  }
}

// 무료 관리형 도메인(자동 검증). fromSenderDomain 으로 실제 발신 도메인이 부여된다.
resource emailDomain 'Microsoft.Communication/emailServices/domains@2023-04-01' = {
  parent: emailService
  name: 'AzureManagedDomain'
  location: 'global'
  tags: tags
  properties: {
    domainManagement: 'AzureManaged'
    userEngagementTracking: 'Disabled'
  }
}

// 발신자 사용자명(donotreply). 관리형 도메인에서 즉시 사용 가능.
resource senderUsername 'Microsoft.Communication/emailServices/domains/senderUsernames@2023-04-01' = {
  parent: emailDomain
  name: 'donotreply'
  properties: {
    username: 'donotreply'
    displayName: 'Haskell Blog'
  }
}

// Communication Services 본체. 위 이메일 도메인을 연결한다.
resource communicationService 'Microsoft.Communication/communicationServices@2023-04-01' = {
  name: 'acs-${resourceToken}'
  location: 'global'
  tags: tags
  properties: {
    dataLocation: acsDataLocation
    linkedDomains: [ emailDomain.id ]
  }
}

// 앱에 주입할 ACS 연결 문자열(시크릿)과 발신자 주소.
var acsConnectionString = communicationService.listKeys().primaryConnectionString
var acsSenderAddress = 'donotreply@${emailDomain.properties.fromSenderDomain}'

// ---------- Key Vault (시크릿 보관) ----------
// 서명 마스터 키(PREVIEW_SECRET)와 DATABASE_URL 을 Vault 에 두고, Container App 은
// 매니지드 ID 로 런타임에 참조한다(값이 IaC·앱 설정에 평문으로 남지 않음).
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'kv-${resourceToken}'
  location: location
  tags: tags
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    publicNetworkAccess: 'Enabled'
  }
}

// 매니지드 ID 에 'Key Vault Secrets User' 권한 부여(시크릿 읽기 전용)
resource kvSecretsUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, identity.id, 'KeyVaultSecretsUser')
  scope: keyVault
  properties: {
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
    // Key Vault Secrets User 역할 정의 ID
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
  }
}

// PREVIEW_SECRET — newGuid() 기본값(배포 시 자동 생성)을 Vault 에 저장.
resource kvPreviewSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'preview-secret'
  properties: {
    value: previewSecret
  }
}

resource kvDatabaseUrl 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'database-url'
  properties: {
    value: databaseUrl
  }
}

// ACS 연결 문자열(액세스 키 포함) — Vault 에 저장하고 앱은 매니지드 ID 로 참조.
resource kvAcsConnString 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'acs-connection-string'
  properties: {
    value: acsConnectionString
  }
}

// ---------- Container App ----------
// 'azd-service-name: web' 태그로 azd가 이미지 배포 대상을 식별한다.
resource web 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'ca-web-${resourceToken}'
  location: location
  tags: union(tags, { 'azd-service-name': 'web' })
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerEnv.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8080
        transport: 'auto'
      }
      registries: [
        {
          server: registry.properties.loginServer
          identity: identity.id
        }
      ]
      secrets: [
        {
          name: 'database-url'
          keyVaultUrl: '${keyVault.properties.vaultUri}secrets/database-url'
          identity: identity.id
        }
        {
          name: 'preview-secret'
          keyVaultUrl: '${keyVault.properties.vaultUri}secrets/preview-secret'
          identity: identity.id
        }
        {
          name: 'acs-connection-string'
          keyVaultUrl: '${keyVault.properties.vaultUri}secrets/acs-connection-string'
          identity: identity.id
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'web'
          image: webImage
          resources: {
            cpu: json('0.5')
            memory: '1.0Gi'
          }
          env: [
            { name: 'PORT', value: '8080' }
            { name: 'DATABASE_URL', secretRef: 'database-url' }
            { name: 'PREVIEW_SECRET', secretRef: 'preview-secret' }
            { name: 'ACS_CONNECTION_STRING', secretRef: 'acs-connection-string' }
            { name: 'ACS_SENDER_ADDRESS', value: acsSenderAddress }
          ]
        }
      ]
      scale: {
        // 비용 절감을 원하면 minReplicas를 0으로 (콜드 스타트 발생).
        minReplicas: 1
        maxReplicas: 5
        rules: [
          {
            name: 'http-scale'
            http: { metadata: { concurrentRequests: '50' } }
          }
        ]
      }
    }
  }
  dependsOn: [ acrPull, kvSecretsUser, kvPreviewSecret, kvDatabaseUrl, kvAcsConnString ]
}

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = registry.properties.loginServer
output WEB_URI string = 'https://${web.properties.configuration.ingress.fqdn}'
