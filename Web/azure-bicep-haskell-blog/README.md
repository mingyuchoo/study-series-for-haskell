# haskell-blog

Haskell(Scotty) + PostgreSQL로 만든 동적 블로그 샘플. **Azure Container Apps**에 배포하며
**PostgreSQL Flexible Server**, **Azure Container Registry**, **GitHub Actions**, **Azure Developer CLI(azd)** 를 사용한다.

## 스택

- 앱: Haskell, Scotty(웹), postgresql-simple + resource-pool(DB), blaze-html(뷰)
- 런타임 이미지: 멀티스테이지 빌드 — `haskell:9.8-slim`으로 빌드, `debian:bookworm-slim`(glibc) 위에서 실행
- 인프라: Azure Container Apps(ACA), PostgreSQL Flexible Server(Burstable B1ms), ACR
- 배포: azd(`azure.yaml` + `infra/*.bicep`), GitHub Actions(OIDC)

## 디렉터리 구조

```
haskell-blog/
├── app/Main.hs              # 진입점
├── src/Blog/                # 라이브러리
│   ├── App.hs               # Scotty 라우트
│   ├── Config.hs            # 환경 변수 설정
│   ├── Database.hs          # 연결 풀 + 쿼리 + 마이그레이션
│   ├── Types.hs             # Post / NewPost
│   └── View.hs              # blaze-html 뷰
├── Dockerfile               # 멀티스테이지 (debian-slim 런타임)
├── docker-compose.yml       # 로컬 개발(앱 + postgres)
├── azure.yaml               # azd 서비스 정의 (host: containerapp)
├── infra/
│   ├── main.bicep           # 구독 스코프, 리소스 그룹
│   ├── resources.bicep      # ACR/ACA/PostgreSQL 등
│   └── main.parameters.json # azd 환경 변수 치환
└── .github/workflows/
    ├── ci.yml               # Haskell 빌드 검증
    └── azure-dev.yml        # azd provision + deploy
```

## 라우트

| 메서드 | 경로           | 설명          |
|--------|----------------|---------------|
| GET    | `/`            | 글 목록       |
| GET    | `/posts/new`   | 새 글 폼      |
| POST   | `/posts`       | 글 생성       |
| GET    | `/posts/:id`   | 글 상세       |
| GET    | `/health`      | 헬스 체크     |

## 로컬 실행

도커로 한 번에:

```bash
docker compose up --build
# http://localhost:8080
```

cabal로 직접 (로컬 postgres가 떠 있어야 함):

```bash
export DATABASE_URL="postgresql://blog:blog@localhost:5432/blog?sslmode=disable"
cabal run haskell-blog
```

## Azure 배포 (azd)

사전 준비: [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) 설치, `az login`.

```bash
# 1) 환경 초기화
azd env new my-blog

# 2) 비밀값 설정 (Bicep의 secure 파라미터로 전달됨)
azd env set POSTGRES_ADMIN_PASSWORD "<강력한-비밀번호>"

# 서명 마스터 키 — 한 번 고정하면 azd 환경에 저장돼 재프로비저닝에도 유지된다.
# (미설정 시 azd가 입력을 요청. 값이 바뀌면 기존 세션·미리보기 토큰이 무효화됨)
azd env set PREVIEW_SECRET "$(openssl rand -base64 32)"

# 3) (선택) 개발자가 DB에 직접 접속하려면 — 본인 공인 IP와 Entra 신원 설정
azd env set DEVELOPER_IP_ADDRESS "$(curl -s ifconfig.me)"
azd env set ENTRA_ADMIN_OBJECT_ID "$(az ad signed-in-user show --query id -o tsv)"
azd env set ENTRA_ADMIN_PRINCIPAL_NAME "$(az ad signed-in-user show --query userPrincipalName -o tsv)"

# 4) 프로비저닝 + 빌드 + 배포 (ACR 푸시 + ACA 이미지 갱신까지)
azd up
```

완료되면 출력의 `WEB_URI`로 접속한다.

### 개발자가 PostgreSQL에 직접 접속하기 (개발 환경)

DB는 공용 엔드포인트를 켜되 **방화벽으로 접근을 좁히고**(앱용 Azure 서비스 규칙 + 위에서 설정한
`DEVELOPER_IP_ADDRESS` 단일 IP), **전송은 TLS(`sslmode=require`)를 강제**한다. 개발자는 공유
admin 비밀번호 대신 **Microsoft Entra 신원**으로 접속한다(`az login` 토큰을 비밀번호로 사용).

```bash
# Entra 액세스 토큰을 비밀번호로 사용해 접속(토큰 유효기간 동안 유효)
export PGPASSWORD="$(az account get-access-token --resource-type oss-rdbms --query accessToken -o tsv)"
psql "host=<psql-...>.postgres.database.azure.com port=5432 dbname=blog sslmode=require \
      user=$(az ad signed-in-user show --query userPrincipalName -o tsv)"
```

서버 FQDN은 `azd env get-values` 또는 포털의 Flexible Server 개요에서 확인한다. IP가 바뀌면
`azd env set DEVELOPER_IP_ADDRESS <새 IP>` 후 `azd provision`으로 방화벽 규칙을 갱신한다.

> 보안 메모: `DEVELOPER_IP_ADDRESS`/`ENTRA_ADMIN_*`를 비워두면 개발자용 방화벽 규칙과 Entra
> 관리자를 만들지 않아 앱만 DB에 접근한다(운영 기본값으로 적합). 노출을 더 줄이려면
> `publicNetworkAccess`를 끄고 Private Endpoint로 전환하는 방향을 권장한다.

### 동작 방식

1. `azd up`이 `infra/main.bicep`으로 리소스 그룹, ACR, ACA 환경, PostgreSQL Flexible Server,
   Container App(처음엔 플레이스홀더 이미지)을 만든다.
2. 이어서 Dockerfile을 빌드해 ACR에 푸시하고, `azd-service-name: web` 태그가 붙은 Container App의
   이미지를 방금 푸시한 이미지로 교체한다.
3. 앱은 ACA가 주입한 `DATABASE_URL` 시크릿(`sslmode=require`)으로 Flexible Server에 연결하고,
   시작 시 `posts` 테이블을 자동 생성한다.

## 커스텀 도메인 연결 (mingyuchoo.com → Azure Container Apps)

`infra/`는 Azure DNS Zone과 apex(`mingyuchoo.com`)·`www` 호스트네임 바인딩, 무료 매니지드
인증서(HTTPS)를 Bicep으로 선언한다. NS 위임(whois.co.kr)과 DNS 전파가 끝나야 인증서가 발급되고,
ACA 매니지드 인증서는 **호스트네임이 컨테이너 앱에 먼저 등록돼 있어야** 발급되므로 **3단계**로 나눠
진행한다. `CUSTOM_DOMAIN_NAME`이 비어 있으면 도메인 리소스를 전혀 만들지 않는다(현행 동작 유지).

```
whois.co.kr (도메인 등록)  ──NS 변경──▶  Azure DNS Zone  ──A/CNAME/TXT──▶  ACA (커스텀 도메인 + 인증서)
```

### 1단계 — DNS Zone + 레코드 생성, 네임서버 위임

```bash
# apex 도메인만 지정(www는 자동 구성). BIND_CUSTOM_DOMAIN은 아직 false(기본값).
azd env set CUSTOM_DOMAIN_NAME mingyuchoo.com
azd provision

# Azure가 발급한 네임서버(NS 4개) 확인 → whois.co.kr의 네임서버로 교체
azd env get-values | grep DNS_NAME_SERVERS
# 또는: az network dns zone show -g rg-<env> -n mingyuchoo.com --query nameServers -o tsv
```

이 단계에서 Bicep이 만드는 것:

- **DNS Zone** `mingyuchoo.com`
- **A** `@` → Container App Environment의 Static IP (루트 도메인은 CNAME 불가 → A 레코드 필수)
- **CNAME** `www` → Container App 기본 FQDN
- **TXT** `asuid`, `asuid.www` → `customDomainVerificationId` (소유권 검증값)

whois.co.kr에서 기존 네임서버를 삭제하고 위 NS 4개를 입력한다. **전파에는 최대 24~48시간**이 걸린다.
`dig NS mingyuchoo.com +short`가 Azure NS를 반환하면 전파 완료다.

### 2단계 — 호스트네임 등록(인증서 없음)

DNS 위임/전파가 끝난 뒤(`dig NS`가 Azure NS 반환) 플래그를 켜고 다시 프로비저닝한다. 이 단계는
인증서를 **발급하지 않고** apex·www 호스트네임만 컨테이너 앱에 등록한다(`bindingType: 'Disabled'`).

```bash
azd env set ADD_CUSTOM_HOSTNAME true
azd provision
```

이 단계에서 Bicep이 추가하는 것:

- Container App ingress의 **`customDomains`** 바인딩 2개(apex/www, `bindingType: 'Disabled'`, 인증서 미연결)
  — `asuid` TXT로 소유권 검증 후 호스트네임이 환경에 등록된다.

### 3단계 — 매니지드 인증서 발급 + SNI/TLS 바인딩

호스트네임이 등록된 뒤에 플래그를 켜고 다시 프로비저닝한다.

```bash
azd env set BIND_CUSTOM_DOMAIN true
azd provision

azd env get-values | grep CUSTOM_DOMAIN_URI   # https://mingyuchoo.com
```

이 단계에서 Bicep이 추가하는 것:

- **매니지드 인증서** 2개(apex/www) — `asuid` TXT로 소유권 검증(`domainControlValidation: 'TXT'`) 후 자동 발급
- Container App ingress의 `customDomains` 바인딩을 **`SniEnabled`(인증서 연결)** 로 승격

> 왜 2·3단계로 나누나: ACA 매니지드 인증서는 "호스트네임이 컨테이너 앱에 이미 등록된 상태"를 전제로만
> 발급된다(`RequireCustomHostnameInEnvironment`). 그런데 `SniEnabled` 바인딩은 인증서를 참조하므로,
> 한 배포에서 인증서 발급과 SNI 바인딩을 동시에 하면 "인증서↔호스트네임" 순환이 생겨 실패한다. 그래서
> 2단계에서 `Disabled`로 호스트네임만 먼저 등록하고, 3단계에서 인증서를 발급하며 `SniEnabled`로 승격한다.
> (DNS 전파 전에 켜도 `asuid` 조회 실패로 멈추므로, 1단계 전파 완료를 먼저 확인할 것. 인증서는 보통 수 분 내 발급.)

## GitHub Actions 자동 배포

```bash
# OIDC 페더레이션 자격 증명 + 저장소 변수/시크릿을 자동 구성
azd pipeline config
```

그다음 `POSTGRES_ADMIN_PASSWORD`와 `PREVIEW_SECRET`을 저장소 시크릿으로 추가하면, `main` 푸시 시
`.github/workflows/azure-dev.yml`이 `azd provision` → `azd deploy`를 수행한다.
(CI는 `--no-prompt`라 두 secure 파라미터를 환경에서 받아야 한다.)

## 정리

```bash
azd down
```

## 참고 / 조정 포인트

- **연결 풀**: `Database.hs`의 최대 연결 수(10)와 유휴 타임아웃(60초)을 워크로드에 맞게 조정.
- **스케일**: `resources.bicep`의 `minReplicas`를 0으로 두면 무트래픽 시 비용이 0에 수렴(콜드 스타트 발생).
- **버전 고정**: 재현 가능한 빌드가 필요하면 `cabal freeze` 후 `cabal.project.freeze`를 커밋.
- **시크릿 관리**: 운영 환경에서는 DB 비밀번호를 Key Vault로 옮기고 ACA에서 참조하는 구성을 권장.
