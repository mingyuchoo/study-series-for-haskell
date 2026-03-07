# Haskell LSP Extension

Haskell을 위한 Language Server Protocol (LSP) 구현 프로젝트로, 다음 두 가지로 구성됩니다:

1. **Haskell LSP Server** - `lsp` 라이브러리를 사용한 Haskell 언어 서버
2. **VSCode Extension** - 서버 라이프사이클을 관리하는 TypeScript 기반 VSCode 확장

## 주요 기능

### 언어 서버 기능
- **문서 동기화**: LSP VFS(Virtual File System) 기반 실시간 문서 추적
- **진단(Diagnostics)**: 파서 기반 구문 오류 감지 및 제어 문자 검출
- **코드 완성**: 타입 시그니처를 포함한 지능형 코드 완성
  - 함수 완성 (타입 정보 포함)
  - 모듈 한정 완성 (예: `Data.List.`)
  - 컨텍스트 인식 제안
- **Hover 정보**: 타입 정보 및 문서 표시
  - 함수 타입 시그니처
  - 타입 정의 및 kind 정보
  - 연산자 고정성(fixity) 정보
- **정의로 이동(Go to Definition)**: 심볼 정의 위치로 이동
- **문서 심볼(Document Symbols)**: 선언문 개요 보기
- **설정 관리**: 실행 중 설정 변경 지원

### VSCode 확장 기능
- **서버 라이프사이클 관리**: 자동 시작/중지/재시작
- **충돌 복구**: 지수 백오프를 통한 자동 재시작
- **설정 동기화**: 실시간 설정 업데이트
- **오류 처리**: 사용자 친화적 오류 메시지 및 복구 옵션

## 설치

### 빠른 시작

1. **전체 빌드**:
   ```bash
   make build-all
   ```

2. **VSCode 확장 설치**:
   ```bash
   make install-extension
   ```

3. **VSCode에서 Haskell 프로젝트를 열면** 확장이 자동으로 LSP 서버를 시작합니다.

### 수동 설치

#### LSP 서버 빌드

```bash
# Haskell LSP 서버 빌드
stack build

# 테스트 실행
stack test

# 로컬 설치
stack install
```

#### VSCode 확장 빌드

```bash
# 확장 디렉토리로 이동
cd vscode-extension

# 의존성 설치
npm install

# TypeScript 컴파일
npm run compile

# 확장 패키징
npm run package

# VSCode에 설치
code --install-extension *.vsix
```

## 사용법

### LSP 서버 실행

LSP 서버를 독립 실행하여 테스트하거나 다른 에디터와 통합할 수 있습니다:

```bash
# 서버 실행 (stdin/stdout 통신)
stack run

# 설치된 실행 파일 실행
haskell-lsp-server

# 로깅과 함께 실행
haskell-lsp-server --log-level debug
```

### VSCode 확장

설치 후 확장은 자동으로:

1. Haskell 파일(`.hs` 또는 `.lhs`) 열 때 **활성화**
2. LSP 서버 프로세스 **시작**
3. 완성, hover, 진단 등 언어 기능 **제공**
4. 서버 라이프사이클 **관리** (충돌 시 재시작, 비활성화 시 종료)

### 설정

VSCode 설정에서 확장을 구성할 수 있습니다:

```json
{
  "haskellLsp.serverPath": "haskell-lsp-server",
  "haskellLsp.logLevel": "info",
  "haskellLsp.maxRestartCount": 3,
  "haskellLsp.enableVerboseLogging": false
}
```

#### 설정 옵션

- **`haskellLsp.serverPath`**: LSP 서버 실행 파일 경로
- **`haskellLsp.logLevel`**: 서버 로그 레벨 (`debug`, `info`, `warning`, `error`)
- **`haskellLsp.maxRestartCount`**: 최대 자동 재시작 횟수
- **`haskellLsp.enableVerboseLogging`**: 상세 로깅 활성화

## 개발

### 프로젝트 구조

```
├── src/                    # Haskell LSP 서버 소스
│   ├── LSP/               # 핵심 LSP 기능
│   │   ├── Server.hs      # 서버 진입점 및 핸들러 등록
│   │   ├── Types.hs       # 핵심 데이터 타입 및 설정
│   │   ├── Diagnostics.hs # 오류 감지 및 보고
│   │   ├── State.hs       # VFS 기반 문서 상태 관리
│   │   └── Error.hs       # 오류 분류 및 복구
│   ├── Handlers/          # 요청/알림 핸들러
│   │   ├── DocumentSync.hs    # 문서 동기화 (열기/변경/닫기)
│   │   ├── Hover.hs           # Hover 정보
│   │   ├── Completion.hs      # 코드 완성
│   │   ├── Definition.hs      # 정의로 이동
│   │   ├── DocumentSymbol.hs  # 문서 심볼
│   │   └── Configuration.hs   # 설정 변경 처리
│   ├── Analysis/          # 코드 분석 및 파싱
│   │   ├── Parser.hs     # Haskell 코드 파서
│   │   └── Highlighter.hs # 구문 강조
│   └── Lib.hs            # CLI 진입점
├── app/                   # 서버 실행 파일 진입점
├── test/                  # 테스트 스위트
├── vscode-extension/      # VSCode 확장
│   ├── src/              # TypeScript 소스
│   └── package.json      # 확장 매니페스트
└── docker/               # Docker 설정
```

### 아키텍처

#### LSP 서버 (Haskell)

서버는 `lsp` 라이브러리의 `ServerDefinition`을 사용하여 LSP 프로토콜을 구현합니다:

- **LSP.Server**: `staticHandlers`에 모든 핸들러를 등록하여 실제 LSP 기능을 제공
- **LSP.State**: LSP 라이브러리의 내장 VFS를 통한 문서 콘텐츠 관리
- **LSP.Types**: `ServerConfig`, `LspMessage`, JSON-RPC 프로토콜 헬퍼
- **LSP.Diagnostics**: 파서 오류 및 제어 문자 감지 기반 진단 엔진
- **Handlers.***: 각 LSP 메서드별 핸들러 (`LspM ServerConfig` 모나드에서 실행)
- **Analysis.Parser**: 정규식 기반 Haskell 코드 파서

#### VSCode 확장 (TypeScript)

- **extension.ts**: 확장 진입점
- **config.ts**: 설정 관리
- Language Client 설정 및 서버 라이프사이클 관리

#### 통신 흐름

```
VSCode Extension ←→ Language Client ←→ LSP Server
     (TypeScript)      (JSON-RPC)      (Haskell)
```

### 빌드 및 테스트

#### Haskell 서버

```bash
# 개발 중 빠른 빌드
stack build --fast

# 최적화 빌드
make build

# 테스트 실행
stack test

# 테스트 감시 모드
make watch-test

# 대화형 개발
make ghcid

# 코드 포매팅
make format
```

#### VSCode 확장

```bash
cd vscode-extension

# 의존성 설치
npm install

# TypeScript 컴파일
npm run compile

# 감시 모드
npm run watch

# 린터 실행
npm run lint

# 확장 패키징
npm run package
```

## 문제 해결

### 자주 발생하는 문제

#### "Server executable not found"

1. 서버가 빌드되었는지 확인: `stack build`
2. 설정에서 서버 경로 확인
3. 절대 경로 사용 시도
4. 실행 파일 권한 확인

#### 서버가 반복적으로 충돌

1. VSCode 출력 패널 확인 (보기 > 출력 > "Haskell LSP")
2. 설정에서 상세 로깅 활성화
3. Haskell 프로젝트가 유효한지 확인
4. VSCode 재시작 시도

#### 언어 기능이 작동하지 않음

1. 확장이 활성화되었는지 확인 (상태 표시줄 확인)
2. 파일이 Haskell로 인식되는지 확인 (`.hs` 또는 `.lhs`)
3. 충돌하는 Haskell 확장이 있는지 확인
4. LSP 서버 재시작: Ctrl+Shift+P > "Haskell LSP: Restart Server"

## 기여하기

기여를 환영합니다! 다음 절차를 따라주세요:

1. 리포지토리 포크
2. 기능 브랜치 생성
3. 변경 사항 구현
4. 새 기능에 대한 테스트 추가
5. 모든 테스트 통과 확인: `make test`
6. Pull Request 제출

### 개발 지침

- 기존 코드 스타일을 따르세요 (Haskell은 `make format` 사용)
- 새 기능에는 테스트를 추가하세요
- 필요에 따라 문서를 업데이트하세요
- 서버와 확장 컴포넌트 모두 테스트하세요

## 감사의 글

- [lsp](https://hackage.haskell.org/package/lsp) Haskell 라이브러리 사용
- [vscode-languageclient](https://www.npmjs.com/package/vscode-languageclient) 기반 VSCode 확장
- Haskell 생태계의 다른 LSP 구현에서 영감을 받음
