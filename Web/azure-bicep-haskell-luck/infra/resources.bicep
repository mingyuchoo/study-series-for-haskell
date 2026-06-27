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

@description('배포를 실행하는 주체의 objectId(azd 가 AZURE_PRINCIPAL_ID 로 자동 주입). RBAC 인증 Key Vault 에 시크릿을 쓰려면 이 주체에 데이터플레인 역할이 필요하다(Contributor 만으로는 부족). 비우면 역할 할당을 건너뛴다.')
param principalId string = ''

@allowed([ 'User', 'Group', 'ServicePrincipal' ])
@description('배포 주체 유형. 로컬(az login)은 User, CI(OIDC)는 ServicePrincipal. 새로 만든 주체의 AAD 복제 지연으로 인한 역할 할당 실패를 줄인다.')
param principalType string = 'User'

@description('배포할 컨테이너 이미지. azd deploy가 실제 이미지를 푸시하기 전까지 사용하는 플레이스홀더.')
param webImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@secure()
@description('JWT 서명 비밀키(JWT_SECRET). main.bicep 이 azd 환경의 고정값을 전달한다. (모듈 단독 배포 시에만 newGuid() 폴백이 동작하며, 그 경우 배포마다 값이 바뀌어 기존 토큰이 무효화됨에 유의.)')
param jwtSecret string = newGuid()

@description('CORS 허용 오리진(콤마 구분). 단일 컨테이너(동일 출처)에서는 비워도 되지만, 커스텀 도메인을 명시해두면 안전하다.')
param allowedOrigins string = ''

@description('관리자 이메일(콤마 구분). 지정하면 "첫 가입자=관리자" 규칙이 비활성화되고 여기 적힌 이메일만 관리자로 승격된다.')
param adminEmails string = ''

@description('연결할 커스텀 도메인(서브도메인). 기본값 lucky.mingyuchoo.com. apex(mingyuchoo.com)는 외부 DNS zone 이 관리하므로 Azure 에 DNS Zone 을 만들지 않는다 — 사용자가 외부 zone 에 CNAME/TXT 를 직접 추가한다. 비우면 커스텀 도메인 바인딩을 건너뛴다.')
param customDomainName string = 'lucky.mingyuchoo.com'

@description('2단계 플래그. true 이면 인증서 없이 호스트네임만 바인딩한다(bindingType: Disabled). 매니지드 인증서 발급의 전제 조건. 외부 zone 에 CNAME/asuid TXT 전파 완료 후 켤 것.')
param addCustomHostname bool = false

@description('3단계 플래그. true 이면 매니지드 인증서 발급 + SNI/TLS 바인딩까지 수행한다. 2단계(addCustomHostname)로 호스트네임이 등록된 뒤에 켤 것.')
param bindCustomDomain bool = false

var databaseName = 'luck'

// 커스텀 도메인 사용 여부. customDomainName 이 비어 있으면 도메인 바인딩 리소스를 건너뛴다.
var useCustomDomain = !empty(customDomainName)
// 호스트네임만 바인딩(2단계). 인증서 없이 hostname 을 등록해 3단계 인증서 발급의 전제 조건을 만든다.
var doAddHostname = useCustomDomain && addCustomHostname
// 인증서 발급/SNI 바인딩(3단계).
var doBindCustomDomain = useCustomDomain && bindCustomDomain

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

// ---------- 사용자 할당 매니지드 ID (ACR Pull / Key Vault 참조용) ----------
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

// ---------- Key Vault (시크릿 보관) ----------
// JWT_SECRET 과 DATABASE_URL 을 Vault 에 두고, Container App 은 매니지드 ID 로 런타임에 참조한다.
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

// 배포 주체(azd 가 주입한 principalId)에 'Key Vault Secrets Officer' 권한 부여.
// RBAC 인증 Vault 에서는 시크릿을 쓰려면 데이터플레인 역할이 필요하다(Contributor 만으로는 403).
resource kvSecretsOfficer 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(principalId)) {
  name: guid(keyVault.id, principalId, 'KeyVaultSecretsOfficer')
  scope: keyVault
  properties: {
    principalId: principalId
    principalType: principalType
    // Key Vault Secrets Officer 역할 정의 ID
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7')
  }
}

// JWT_SECRET — azd 환경의 고정값을 Vault 에 저장.
resource kvJwtSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'jwt-secret'
  properties: {
    value: jwtSecret
  }
  dependsOn: [ kvSecretsOfficer ]
}

resource kvDatabaseUrl 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'database-url'
  properties: {
    value: databaseUrl
  }
  dependsOn: [ kvSecretsOfficer ]
}

// ---------- 커스텀 도메인 바인딩 구성(2·3단계에서 채워짐) ----------
// ACA 매니지드 인증서는 "호스트네임이 이미 컨테이너 앱에 등록된 상태"를 전제로만 발급된다.
// 따라서 호스트네임 등록(Disabled)과 인증서 발급(SniEnabled)을 3단계로 나눈다.
//   1단계: 빈 배열 → 기본 FQDN 만. 사용자가 외부 zone 에 CNAME(lucky)/TXT(asuid.lucky)를 추가하고 전파를 기다린다.
//   2단계(doAddHostname): bindingType 'Disabled' → 호스트네임만 등록(인증서 전제 조건).
//   3단계(doBindCustomDomain): 매니지드 인증서 발급 + SniEnabled 로 승격.
var customDomainsConfig = doBindCustomDomain ? [
  {
    name: customDomainName
    bindingType: 'SniEnabled'
    certificateId: cert.id
  }
] : doAddHostname ? [
  {
    name: customDomainName
    bindingType: 'Disabled'
  }
] : []

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
        customDomains: customDomainsConfig
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
          name: 'jwt-secret'
          keyVaultUrl: '${keyVault.properties.vaultUri}secrets/jwt-secret'
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
            { name: 'APP_ENV', value: 'production' }
            { name: 'DATABASE_URL', secretRef: 'database-url' }
            { name: 'JWT_SECRET', secretRef: 'jwt-secret' }
            { name: 'ALLOWED_ORIGINS', value: allowedOrigins }
            { name: 'ADMIN_EMAILS', value: adminEmails }
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
  dependsOn: [ acrPull, kvSecretsUser, kvJwtSecret, kvDatabaseUrl ]
}

// ---------- 매니지드 인증서 (HTTPS, 3단계에서만) ----------
// 외부 zone 의 asuid.<sub> TXT 로 소유권을 검증(domainControlValidation: 'TXT')한 뒤 무료 인증서를 발급한다.
// 호스트네임이 2단계(addCustomHostname=true)에서 이미 등록돼 있어야 발급에 성공한다.
resource cert 'Microsoft.App/managedEnvironments/managedCertificates@2024-03-01' = if (doBindCustomDomain) {
  parent: containerEnv
  name: 'cert-${resourceToken}'
  location: location
  tags: tags
  properties: {
    subjectName: customDomainName
    domainControlValidation: 'TXT'
  }
}

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = registry.properties.loginServer
output WEB_URI string = 'https://${web.properties.configuration.ingress.fqdn}'

// 커스텀 도메인 운영용 출력값(외부 DNS zone 에 레코드를 직접 추가할 때 사용).
//   WEB_FQDN: CNAME(lucky) 의 대상.
//   WEB_CUSTOM_DOMAIN_VERIFICATION_ID: TXT(asuid.lucky) 의 값.
output WEB_FQDN string = web.properties.configuration.ingress.fqdn
output CONTAINER_ENV_STATIC_IP string = containerEnv.properties.staticIp
output WEB_CUSTOM_DOMAIN_VERIFICATION_ID string = web.properties.customDomainVerificationId
output CUSTOM_DOMAIN_URI string = doBindCustomDomain ? 'https://${customDomainName}' : ''
