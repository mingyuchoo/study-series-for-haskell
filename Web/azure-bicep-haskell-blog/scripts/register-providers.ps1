#!/usr/bin/env pwsh
<#
.SYNOPSIS
    azd preprovision 훅: 이 템플릿이 사용하는 Azure 리소스 공급자(RP)를 등록한다.

.DESCRIPTION
    신규 구독에서는 일부 RP(특히 Microsoft.Communication)가 자동 등록돼 있지 않아
    첫 'azd provision' 이 MissingSubscriptionRegistration 으로 실패한다. 등록은 멱등이며
    이미 Registered 상태면 즉시 통과한다. 등록 전파에는 수십 초가 걸릴 수 있어 대기한다.
#>
$ErrorActionPreference = 'Stop'

# 이 템플릿의 Bicep 이 만드는 리소스가 의존하는 RP 목록.
$Providers = @(
    'Microsoft.App',
    'Microsoft.ContainerRegistry',
    'Microsoft.DBforPostgreSQL',
    'Microsoft.OperationalInsights',
    'Microsoft.KeyVault',
    'Microsoft.ManagedIdentity',
    'Microsoft.Communication',
    'Microsoft.Network'
)

function Write-Log { param([string]$Message) Write-Host "==> $Message" -ForegroundColor Blue }
function Write-Err { param([string]$Message) Write-Host "[error] $Message" -ForegroundColor Red }

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Err "'az'(Azure CLI) 를 찾을 수 없습니다. RP 등록을 위해 설치 후 다시 시도하세요."
    exit 1
}

# azd 가 선택한 구독으로 az 컨텍스트를 맞춘다(설정돼 있으면).
if ($env:AZURE_SUBSCRIPTION_ID) {
    az account set --subscription $env:AZURE_SUBSCRIPTION_ID 2>$null | Out-Null
}

# 1) 미등록 RP 에 등록 요청을 보낸다(이미 등록돼 있으면 az 가 알아서 통과).
foreach ($rp in $Providers) {
    $state = (az provider show --namespace $rp --query registrationState -o tsv 2>$null)
    if (-not $state) { $state = 'Unknown' }
    if ($state -eq 'Registered') {
        Write-Log "${rp}: 이미 등록됨"
    }
    else {
        Write-Log "${rp}: 등록 요청 ($state)"
        az provider register --namespace $rp | Out-Null
    }
}

# 2) 모든 RP 가 Registered 가 될 때까지 대기(최대 ~5분). 전파가 끝나야 provision 이 안전하다.
foreach ($rp in $Providers) {
    $state = 'Unknown'
    for ($i = 0; $i -lt 60; $i++) {
        $state = (az provider show --namespace $rp --query registrationState -o tsv 2>$null)
        if ($state -eq 'Registered') { break }
        Start-Sleep -Seconds 5
    }
    if ($state -ne 'Registered') {
        Write-Err "$rp 등록이 제한 시간 내에 완료되지 않았습니다(현재: $state). 잠시 후 다시 'azd provision' 하세요."
        exit 1
    }
    Write-Log "${rp}: Registered"
}

Write-Log '리소스 공급자 등록 완료'
