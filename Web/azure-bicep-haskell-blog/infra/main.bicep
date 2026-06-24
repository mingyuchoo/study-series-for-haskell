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

@description('ACS(이메일) 데이터 저장 위치. azd env set ACS_DATA_LOCATION <값>. 예: United States, Europe, Asia Pacific.')
param acsDataLocation string = 'United States'

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
    acsDataLocation: acsDataLocation
  }
}

output AZURE_LOCATION string = location
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = resources.outputs.AZURE_CONTAINER_REGISTRY_ENDPOINT
output WEB_URI string = resources.outputs.WEB_URI
