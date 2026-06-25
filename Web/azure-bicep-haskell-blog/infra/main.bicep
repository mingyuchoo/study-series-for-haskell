targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('azd 환경 이름. 리소스 이름 파생에 사용된다.')
param environmentName string

@minLength(1)
@description('모든 리소스의 기본 위치')
param location string

@description('PostgreSQL 관리자 로그인 이름')
param postgresAdminLogin string = 'blogadmin'

@secure()
@description('PostgreSQL 관리자 비밀번호. azd env set POSTGRES_ADMIN_PASSWORD <값> 으로 설정.')
param postgresAdminPassword string

@secure()
@minLength(16)
@description('서명 마스터 키(PREVIEW_SECRET). azd env set PREVIEW_SECRET <값> 으로 한 번 설정하면 azd 환경에 저장돼 재프로비저닝에도 고정된다(미설정 시 azd가 1회 입력을 요청). 값이 바뀌면 기존 세션·미리보기 토큰이 무효화됨.')
param previewSecret string

@description('개발자가 DB 에 직접 접속할 공인 IP. azd env set DEVELOPER_IP_ADDRESS <IP>. 비우면 방화벽에 개발자 규칙 없음.')
param developerIpAddress string = ''

@description('PostgreSQL Entra 관리자 주체 objectId. azd env set ENTRA_ADMIN_OBJECT_ID <objectId>. 비우면 Entra 관리자 미생성.')
param entraAdminObjectId string = ''

@description('Entra 관리자 주체 표시 이름(UPN/이메일 또는 그룹명).')
param entraAdminPrincipalName string = ''

@allowed([ 'User', 'Group', 'ServicePrincipal' ])
@description('Entra 관리자 주체 유형.')
param entraAdminPrincipalType string = 'User'

@description('배포를 실행하는 주체의 objectId. azd 가 AZURE_PRINCIPAL_ID 환경값으로 자동 주입한다. RBAC 인증 Key Vault 에 시크릿을 쓰기 위한 데이터플레인 역할 부여에 사용된다.')
param principalId string = ''

@allowed([ 'User', 'Group', 'ServicePrincipal' ])
@description('배포 주체 유형. 로컬(az login)은 User, CI(OIDC)는 ServicePrincipal. azd env set AZURE_PRINCIPAL_TYPE ServicePrincipal 또는 워크플로 env 로 설정.')
param principalType string = 'User'

@description('ACS(이메일) 데이터 저장 위치. azd env set ACS_DATA_LOCATION <값>. 예: United States, Europe, Asia Pacific.')
param acsDataLocation string = 'United States'

@description('연결할 커스텀 도메인(apex). 예: mingyuchoo.com. 비우면 커스텀 도메인 비활성화. azd env set CUSTOM_DOMAIN_NAME mingyuchoo.com')
param customDomainName string = ''

@description('2단계 플래그. true 이면 인증서 없이 호스트네임만 바인딩한다(매니지드 인증서 발급의 전제 조건). DNS NS 위임/전파 완료 후 켤 것. azd env set ADD_CUSTOM_HOSTNAME true')
param addCustomHostname bool = false

@description('3단계 플래그. true 이면 매니지드 인증서 발급 + SNI/TLS 바인딩까지 수행한다. 2단계(addCustomHostname)로 호스트네임 등록 후 켤 것. azd env set BIND_CUSTOM_DOMAIN true')
param bindCustomDomain bool = false

var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

module resources 'resources.bicep' = {
  name: 'resources'
  scope: rg
  params: {
    location: location
    resourceToken: resourceToken
    tags: tags
    postgresAdminLogin: postgresAdminLogin
    postgresAdminPassword: postgresAdminPassword
    previewSecret: previewSecret
    developerIpAddress: developerIpAddress
    entraAdminObjectId: entraAdminObjectId
    entraAdminPrincipalName: entraAdminPrincipalName
    entraAdminPrincipalType: entraAdminPrincipalType
    principalId: principalId
    principalType: principalType
    acsDataLocation: acsDataLocation
    customDomainName: customDomainName
    addCustomHostname: addCustomHostname
    bindCustomDomain: bindCustomDomain
  }
}

output AZURE_LOCATION string = location
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = resources.outputs.AZURE_CONTAINER_REGISTRY_ENDPOINT
output WEB_URI string = resources.outputs.WEB_URI

// 커스텀 도메인 운영용 출력값(azd env 에 자동 저장됨).
output DNS_ZONE_NAME string = resources.outputs.DNS_ZONE_NAME
output DNS_NAME_SERVERS array = resources.outputs.DNS_NAME_SERVERS
output CONTAINER_ENV_STATIC_IP string = resources.outputs.CONTAINER_ENV_STATIC_IP
output WEB_CUSTOM_DOMAIN_VERIFICATION_ID string = resources.outputs.WEB_CUSTOM_DOMAIN_VERIFICATION_ID
output CUSTOM_DOMAIN_URI string = resources.outputs.CUSTOM_DOMAIN_URI
