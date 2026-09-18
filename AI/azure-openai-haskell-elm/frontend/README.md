# OpenAI Chat Assistant - Elm Frontend (Clean Architecture)

React/TypeScript 프론트엔드를 Elm으로 포팅하고 Clean Architecture로 리팩토링한 버전입니다.

## 필수 요구사항

- [Elm](https://guide.elm-lang.org/install/elm.html) 0.19.2 이상

## 설치

```bash
# Elm 설치 (아직 설치하지 않은 경우)
bun install -g elm        \
               elm-format \
               elm-live

# 프로젝트 디렉토리로 이동
cd frontend

# Elm 패키지 설치
elm make src/Main.elm
```

## 개발

```bash
# Elm 애플리케이션 빌드
elm make src/Main.elm --output=public/elm.js

# 개발 서버 실행 (간단한 HTTP 서버 필요)
# Python 3를 사용하는 경우:
cd public
python3 -m http.server 8000

# 또는 Node.js http-server를 사용하는 경우:
npx http-server public -p 8000
```

브라우저에서 `http://localhost:8000`을 열어 애플리케이션을 확인하세요.

## 프로덕션 빌드

```bash
# 최적화된 빌드
elm make src/Main.elm --output=public/elm.js --optimize
```

## Clean Architecture 구조

```
frontend/src/
├── Main.elm                          # 애플리케이션 진입점
├── Domain/                           # 도메인 계층 (비즈니스 로직)
│   ├── Message.elm                   # 메시지 엔티티
│   └── ChatService.elm               # 채팅 서비스 인터페이스
├── Application/                      # 애플리케이션 계층 (유스케이스)
│   ├── ChatState.elm                 # 채팅 상태 관리
│   └── ChatUseCase.elm               # 채팅 유스케이스
├── Infrastructure/                   # 인프라 계층 (외부 의존성)
│   ├── Http/
│   │   ├── ChatApi.elm               # HTTP API 클라이언트
│   │   └── Decoder.elm               # JSON 디코더
│   └── Error.elm                     # 에러 처리
└── Presentation/                     # 프레젠테이션 계층 (UI)
    ├── View.elm                      # 메인 뷰
    └── Components/
        ├── Header.elm                # 헤더 컴포넌트
        ├── MessageList.elm           # 메시지 리스트
        └── InputArea.elm             # 입력 영역
```

## Clean Architecture 계층 설명

### 1. Domain (도메인 계층)
- **Message.elm**: 메시지 엔티티와 Role 타입 정의
- **ChatService.elm**: 채팅 서비스 인터페이스 (포트)
- 비즈니스 규칙과 엔티티를 정의하며, 외부 의존성이 없음

### 2. Application (애플리케이션 계층)
- **ChatState.elm**: 채팅 상태 관리 (불변 상태 업데이트)
- **ChatUseCase.elm**: 채팅 유스케이스 (메시지 전송, 응답 처리 등)
- 비즈니스 로직을 조율하며, 도메인 계층만 의존

### 3. Infrastructure (인프라 계층)
- **Http/ChatApi.elm**: HTTP API 클라이언트 구현
- **Http/Decoder.elm**: JSON 인코더/디코더
- **Error.elm**: HTTP 에러 처리
- 외부 시스템과의 통신을 담당

### 4. Presentation (프레젠테이션 계층)
- **View.elm**: 메인 뷰 조합
- **Components/**: 재사용 가능한 UI 컴포넌트
- UI 렌더링과 사용자 상호작용 처리

### 5. Main (진입점)
- 모든 계층을 조합하여 애플리케이션 실행
- Elm Architecture (Model-Update-View) 패턴 적용

## 주요 기능

- ✅ 채팅 메시지 송수신
- ✅ 로딩 상태 표시
- ✅ 에러 처리
- ✅ Enter 키로 메시지 전송
- ✅ 채팅 초기화
- ✅ 반응형 UI
- ✅ Clean Architecture 적용
- ✅ 계층 간 명확한 의존성 분리

## API 설정

`public/index.html` 파일에서 API URL을 변경할 수 있습니다:

```javascript
const apiUrl = 'http://localhost:8000';  // 백엔드 API URL
```

## Clean Architecture의 장점

1. **관심사의 분리**: 각 계층이 명확한 책임을 가짐
2. **테스트 용이성**: 각 계층을 독립적으로 테스트 가능
3. **유지보수성**: 변경 사항이 특정 계층에 국한됨
4. **확장성**: 새로운 기능 추가가 용이
5. **의존성 규칙**: 외부 계층이 내부 계층을 의존 (역방향 의존성 없음)

## 의존성 방향

```
Presentation → Application → Domain ← Infrastructure
```

- Presentation은 Application과 Infrastructure를 의존
- Application은 Domain만 의존
- Infrastructure는 Domain을 의존
- Domain은 어떤 계층도 의존하지 않음 (순수 비즈니스 로직)

## 원본 프로젝트와의 차이점

- React Hooks 대신 Elm 아키텍처 사용
- TypeScript 대신 Elm의 강력한 타입 시스템 사용
- 런타임 에러가 없는 순수 함수형 프로그래밍
- 컴파일 타임에 모든 에러 검출
- Clean Architecture 패턴 적용으로 계층 분리
