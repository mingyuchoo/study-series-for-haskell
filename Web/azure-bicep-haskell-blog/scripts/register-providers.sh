#!/usr/bin/env sh
#
# azd preprovision 훅: 이 템플릿이 사용하는 Azure 리소스 공급자(RP)를 등록한다.
#
# 신규 구독에서는 일부 RP(특히 Microsoft.Communication)가 자동 등록돼 있지 않아
# 첫 'azd provision' 이 MissingSubscriptionRegistration 으로 실패한다. 등록은 멱등이며
# 이미 Registered 상태면 즉시 통과한다. 등록 전파에는 수십 초가 걸릴 수 있어 대기한다.
set -eu

# 이 템플릿의 Bicep 이 만드는 리소스가 의존하는 RP 목록.
PROVIDERS="Microsoft.App \
Microsoft.ContainerRegistry \
Microsoft.DBforPostgreSQL \
Microsoft.OperationalInsights \
Microsoft.KeyVault \
Microsoft.ManagedIdentity \
Microsoft.Communication \
Microsoft.Network"

log() { printf '==> %s\n' "$*"; }
err() { printf '[error] %s\n' "$*" >&2; }

if ! command -v az >/dev/null 2>&1; then
  err "'az'(Azure CLI) 를 찾을 수 없습니다. RP 등록을 건너뛸 수 없으므로 설치 후 다시 시도하세요."
  exit 1
fi

# azd 가 선택한 구독으로 az 컨텍스트를 맞춘다(설정돼 있으면).
if [ "${AZURE_SUBSCRIPTION_ID:-}" != "" ]; then
  az account set --subscription "${AZURE_SUBSCRIPTION_ID}" >/dev/null 2>&1 || true
fi

# 1) 미등록 RP 에 등록 요청을 보낸다(이미 등록돼 있으면 az 가 알아서 통과).
for rp in $PROVIDERS; do
  state="$(az provider show --namespace "$rp" --query registrationState -o tsv 2>/dev/null || echo Unknown)"
  if [ "$state" = "Registered" ]; then
    log "$rp: 이미 등록됨"
  else
    log "$rp: 등록 요청 ($state)"
    az provider register --namespace "$rp" >/dev/null
  fi
done

# 2) 모든 RP 가 Registered 가 될 때까지 대기(최대 ~5분). 전파가 끝나야 provision 이 안전하다.
for rp in $PROVIDERS; do
  i=0
  while [ "$i" -lt 60 ]; do
    state="$(az provider show --namespace "$rp" --query registrationState -o tsv 2>/dev/null || echo Unknown)"
    if [ "$state" = "Registered" ]; then
      break
    fi
    i=$((i + 1))
    sleep 5
  done
  if [ "$state" != "Registered" ]; then
    err "$rp 등록이 제한 시간 내에 완료되지 않았습니다(현재: $state). 잠시 후 다시 'azd provision' 하세요."
    exit 1
  fi
  log "$rp: Registered"
done

log "리소스 공급자 등록 완료"
