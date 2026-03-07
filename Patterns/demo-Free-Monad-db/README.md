# demo-Free-Monad-db

Free Monad 패턴을 활용한 DB 조회 시뮬레이션 데모 프로젝트입니다.

## 개발 환경

| 항목 | 버전 |
|------|------|
| Stack resolver | [lts-24.20](https://www.stackage.org/lts-24.20) |
| GHC | 9.10.3 |
| Language | GHC2024 |

## 의존성

| 패키지 | 용도 |
|--------|------|
| `base >= 4.18 && < 5` | 기본 라이브러리 |
| `free` | Free Monad 구현 (`Control.Monad.Free`) |
| `hspec` | BDD 스타일 테스트 프레임워크 |
| `silently` | IO 출력 캡처 (테스트용) |
| `doctest` / `doctest-discover` | 문서 테스트 |

## 프로젝트 구조

```
src/Lib.hs    -- Free Monad DSL 정의, 스마트 생성자, 인터프리터
app/Main.hs   -- 실행 진입점
test/Spec.hs  -- HSpec 기반 테스트 (IO 출력 검증 포함)
```

## 빌드 및 실행

```bash
# 프로젝트 생성
stack new <project-name> mingyuchoo/new-template

# 빌드
stack build

# 빌드 (워치 모드)
stack build --fast --file-watch --ghc-options "-j4 +RTS -A128m -n2m -RTS"

# 실행
stack run

# 테스트
stack test

# 테스트 (워치 모드)
stack test --fast --file-watch --watch-all

# 테스트 (커버리지 포함)
stack test --coverage --fast --file-watch --watch-all --haddock

# ghcid로 테스트
ghcid --command "stack ghci test/Spec.hs"
```

`Makefile`로도 위 작업들을 수행할 수 있습니다.

## 실행 결과

```
[FreeLog] Starting Free Monad app...
Querying DB...
[FreeLog] Got user: User_99
```

## 아키텍처 패턴 설명

### Free Monad

프로그램을 **데이터(AST, 추상 구문 트리)**로 만듭니다.
비즈니스 로직은 "나는 이것을 하고 싶다"라는 명세서(데이터)를 작성하는 것이고,
실행은 그 명세서를 받아 실제로 수행하는 별도의 인터프리터가 담당합니다.

#### 특징

- **장점**: 로직(순수 데이터)과 해석(Interpreter)이 완벽하게 분리됩니다. 프로그램의 흐름을 데이터로 가지고 있으므로 실행 전에 검사하거나 변경하기 쉽습니다.
- **단점**: 실행 시 트리를 순회해야 하므로 런타임 오버헤드가 있습니다. 보일러플레이트 코드가 다소 발생합니다.
- **의존성**: `package.yaml` 파일에 추가해야할 의존성: `free`

#### DSL 구성 요소

| 구성 요소 | 역할 | 설명 |
|-----------|------|------|
| `AppF` | Functor | DSL 명령어 정의 (`LogMsg`, `GetUser`) |
| `App` | 타입 별칭 | `Free AppF` - Free Monad 타입 |
| `logMsg` | 스마트 생성자 | 로그 메시지 출력 명령 생성 |
| `getUser` | 스마트 생성자 | 사용자 ID로 사용자 조회 명령 생성 |
| `program` | 비즈니스 로직 | 순수 데이터로서의 프로그램 (AST) |
| `runApp` | 인터프리터 | AST를 IO로 해석하는 자연 변환 |
| `someFunc` | 진입점 | `runApp program` 실행 |

#### 동작 흐름

```
program (순수 데이터 생성)
  │
  ├─ LogMsg "Starting Free Monad app..."
  ├─ GetUser 99
  └─ LogMsg "Got user: User_99"
  │
  ▼
runApp (인터프리터가 IO로 해석)
  │
  ├─ putStrLn "[FreeLog] Starting Free Monad app..."
  ├─ putStrLn "Querying DB..." → "User_99" 반환
  └─ putStrLn "[FreeLog] Got user: User_99"
```

#### 테스트

`silently` 패키지의 `capture_`를 사용하여 IO 출력을 캡처하고 검증합니다.

```haskell
-- 전체 프로그램 출력 검증
output <- capture_ someFunc
output `shouldContain` "[FreeLog] Starting Free Monad app..."

-- 개별 DSL 명령어 검증
output <- capture_ $ runApp (logMsg "hello")
output `shouldContain` "[FreeLog] hello"
```
