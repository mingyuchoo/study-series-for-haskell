# llm-safe

LLM 응답의 비결정성을 Haskell 타입 시스템으로 격리하고 검증하는 프레임워크.

비결정적 결과(`LlmResponse`)는 반드시 검증 관문(`verify`, `verifyWith`, `verifyByConsensus`)을 통과해야 `Verified` 타입을 얻을 수 있으며, 이 규칙은 컴파일러가 강제한다.

## 목적

LLM은 동일한 입력에도 다른 응답을 생성한다. 이 불확실성을 런타임 버그가 아닌 **타입 수준의 설계**로 제어하는 것이 이 프로젝트의 핵심이다.

```
LlmResponse<String>   →   [검증 관문]   →   Verified<Int>
  (비결정적 영역)                            (결정적 영역)
```

`Verified` 생성자는 외부로 노출되지 않으므로, `LlmSafe.Verify` 모듈을 우회하여 `Verified` 값을 만드는 것은 불가능하다.

## 아키텍처

```
┌─────────────────────────────────────────┐
│          비결정적 영역 (IO)               │
│                                         │
│  User Input → TUI → callLlm/callLlmN   │
│                 ↓                       │
│         LlmResponse<String>             │
└─────────────────────────────────────────┘
                  ↓ 타입 경계
┌─────────────────────────────────────────┐
│         검증 관문 (LlmSafe.Verify)       │
│                                         │
│  verifyWith parseIntFromText (> 0)      │
│  → Either LlmError (Verified Int)       │
└─────────────────────────────────────────┘
                  ↓ 타입 경계
┌─────────────────────────────────────────┐
│        결정적 영역 (순수 함수)            │
│                                         │
│  classifyPopulation :: Verified Int     │
│                     -> String           │
└─────────────────────────────────────────┘
```

## 모듈 구조

| 모듈 | 역할 |
|------|------|
| `LlmSafe.Types` | 핵심 타입: `LlmResponse`, `Verified`, `LlmError`, `LlmConfig` |
| `LlmSafe.Client` | Azure OpenAI API 호출, N개 병렬 실행 (`callLlm`, `callLlmN`) |
| `LlmSafe.Verify` | 검증 관문 — `Verified` 값을 생성하는 유일한 경로 |
| `LlmSafe.Pipeline` | 검증과 결정적 처리를 조합한 파이프라인 |
| `app/Main.hs` | Brick 기반 터미널 UI |

## 검증 전략

### 1. 단순 검증 (`verify`)

술어 함수로 LLM 응답을 검증한다.

```haskell
verify (not . null) "빈 응답" response
-- Right (Verified "Seoul")
```

### 2. 신뢰도 기반 검증 (`verifyConfidence`)

응답의 신뢰도가 최소 수준 이상일 때만 통과한다.

```haskell
verifyConfidence Medium response
-- Right (Verified "Seoul")
```

### 3. 구조적 검증 (`verifyWith`)

파싱과 술어 검증을 동시에 수행한다.

```haskell
verifyWith parseIntFromText (> 0) response
-- Right (Verified 9500000)
```

### 4. 합의 기반 검증 (`verifyByConsensus`)

N번 병렬 호출 후 다수결 투표로 결과를 결정한다 (Self-Consistency 기법).

```haskell
verifyByConsensus parseIntFromText [r1, r2, r3]
-- Right (Verified 9500000)  -- 과반수가 동의한 값
```

## 오류 타입

```haskell
data LlmError
  = VerificationFailed String   -- 술어 조건 불충족
  | ConsensusNotReached String  -- 다수결 미달
  | ParseError String           -- 파싱 실패
  | RetryExhausted Int          -- 재시도 횟수 초과
  | LowConfidence Confidence    -- 신뢰도 부족
```

## 환경 변수 설정

프로젝트 루트에 `.env` 파일을 생성한다.

```env
AZURE_OPENAI_ENDPOINT=https://<your-resource>.openai.azure.com
AZURE_OPENAI_API_KEY=<your-api-key>
AZURE_OPENAI_DEPLOYMENT=gpt-4o-mini        # 기본값: gpt-5-mini
AZURE_OPENAI_API_VERSION=2024-12-01-preview
LLM_CONSENSUS_COUNT=3                      # 합의 기반 호출 횟수
```

## 빌드 및 실행

```bash
# 빌드
stack build

# 실행 (TUI 애플리케이션)
stack run

# 테스트
stack test
```

## Docker 실행

```bash
cd docker
docker-compose up
```

## TUI 사용법

애플리케이션 실행 후:

| 키 | 동작 |
|----|------|
| 입력 후 `Enter` | 도시 이름으로 인구 조회 |
| `Tab` | 단일 호출 / 합의 기반 모드 전환 |
| `Ctrl+C` | 종료 |

## 의존성

| 라이브러리 | 용도 |
|-----------|------|
| `aeson` | JSON 파싱 |
| `http-client`, `http-client-tls` | Azure OpenAI HTTP 호출 |
| `async` | 병렬 LLM 에이전트 실행 |
| `brick`, `vty` | 터미널 UI |
| `dotenv` | `.env` 파일 로드 |
| `hspec`, `QuickCheck` | 테스트 |

## 라이선스

MIT © 2025 mingyuchoo
