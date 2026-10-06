# TUI Todo 문서

TUI Todo 애플리케이션의 아키텍처, 모듈 구조, 다국어 지원에 대한 종합 문서입니다.

## 문서 목록

### 1. [아키텍처 가이드](ARCHITECTURE.md)
애플리케이션의 전체 아키텍처와 설계 원칙을 설명합니다.

**주요 내용**:
- 프로젝트 구조
- 모듈별 역할
- MTL 아키텍처
- 데이터 흐름
- 설계 원칙
- 확장 가이드

### 2. [모듈 구조 및 리팩토링](MODULE_ORGANIZATION.md)
600줄 이상의 Lib.hs를 여러 모듈로 분리한 리팩토링 과정을 설명합니다.

**주요 내용**:
- 리팩토링 전후 비교
- 모듈별 상세 설명
- 모듈 간 의존성
- 마이그레이션 가이드
- 확장 가이드
- 리팩토링의 이점

### 3. [순수 함수 vs 효과 모듈](PURE_VS_EFFECT_MODULES.md)
각 모듈을 순수(Pure) 코드와 효과(Effect) 코드로 분류하여 분석합니다.

**주요 내용**:
- 순수 모듈 분석
- 효과 모듈 분석
- 분류 요약
- 설계 원칙
- 아키텍처 패턴
- 테스트 전략

### 4. [다국어 지원 가이드](INTERNATIONALIZATION_GUIDE.md)
영어와 한국어 다국어 지원 구현에 대한 상세 가이드입니다.

**주요 내용**:
- 지원 언어
- 언어 설정 방법
- 메시지 파일 구조
- 다국어 처리된 UI 요소
- 구현 세부사항
- 새 언어 추가하기
- MTL 아키텍처 준수
- 유지보수 가이드

### 5. [키 바인딩](KEY_BINDINGS.md)
키보드 단축키 설정 및 커스터마이징 가이드입니다.

### 6. [기존 문서들](.)
- `I18N_IMPLEMENTATION.md`: 다국어 구현 완료 보고서
- `INTERNATIONALIZATION.md`: 다국어 지원 개요
- `REFACTORING_MODULES.md`: 모듈 리팩토링 요약
- `REFACTORING_SUMMARY.md`: 리팩토링 전체 요약

## 빠른 시작

### 애플리케이션 실행
```bash
stack build
stack exec tto
```

### 언어 변경
`src/Lib.hs` 수정:
```haskell
app :: IO ()
app = appWithLanguage I18n.Korean  -- 또는 I18n.English
```

### 키 바인딩 커스터마이징
`config/keybindings.yaml` 또는 `config/keybindings-vim.yaml` 수정

## 프로젝트 구조

```
tto/
├── app/
│   └── Main.hs                    # 진입점
├── src/
│   ├── App.hs                     # MTL 애플리케이션 로직
│   ├── Config.hs                  # 설정 파일 로딩
│   ├── DB.hs                      # 데이터베이스 작업
│   ├── I18n.hs                    # 다국어 지원
│   ├── Lib.hs                     # 애플리케이션 통합
│   └── UI/
│       ├── Types.hs               # 데이터 타입
│       ├── Attributes.hs          # UI 스타일
│       ├── Draw.hs                # UI 렌더링
│       └── Events.hs              # 이벤트 처리
├── config/
│   ├── messages-en.yaml           # 영어 메시지
│   ├── messages-ko.yaml           # 한국어 메시지
│   ├── keybindings.yaml           # 기본 키바인딩
│   └── keybindings-vim.yaml       # Vim 스타일 키바인딩
├── docs/
│   ├── README.md                  # 이 문서
│   ├── ARCHITECTURE.md
│   ├── MODULE_ORGANIZATION.md
│   ├── PURE_VS_EFFECT_MODULES.md
│   └── INTERNATIONALIZATION_GUIDE.md
└── test/
    └── ...                        # 테스트 파일들
```

## 주요 기능

### 할일 관리
- ✅ 할일 추가, 수정, 삭제
- ✅ 완료 상태 토글
- ✅ 상세 정보 보기
- ✅ 다중 필드 지원 (주체자, 대상자, 작업대상)

### 사용자 인터페이스
- ✅ 터미널 기반 UI (Brick)
- ✅ 키보드 단축키
- ✅ 다국어 지원 (영어, 한국어)
- ✅ 커스터마이징 가능한 키바인딩

### 데이터 저장
- ✅ SQLite 데이터베이스
- ✅ 생성/완료 시각 자동 기록
- ✅ 샘플 데이터 자동 생성

## 기술 스택

- **언어**: Haskell
- **빌드 도구**: Stack
- **UI 라이브러리**: Brick
- **데이터베이스**: SQLite (sqlite-simple)
- **설정 파일**: YAML (yaml)
- **아키텍처**: MTL (Monad Transformer Library)

## 설계 철학

1. **순수 함수와 효과 분리**: UI 렌더링은 순수, I/O는 효과
2. **타입 안전성**: 강타입 시스템 활용
3. **모듈화**: 역할별로 명확히 분리
4. **테스트 가능성**: MTL 패턴으로 의존성 주입
5. **확장 가능성**: 새 기능 추가 시 기존 코드 최소 변경

## 개발 가이드

### 새 기능 추가
1. 데이터 타입이 필요하면 `UI/Types.hs`에 추가
2. UI 렌더링이 필요하면 `UI/Draw.hs`에 추가
3. 이벤트 처리가 필요하면 `UI/Events.hs`에 추가
4. 데이터베이스 작업이 필요하면 `DB.hs`와 `App.hs`에 추가

### 테스트 작성
- 순수 함수: 단위 테스트
- 효과 함수: 통합 테스트 (Mock DB 사용)

### 코드 스타일
- `stylish-haskell` 사용
- 명확한 타입 시그니처
- 간결한 함수 (20줄 이하 권장)

## 기여 가이드

1. 이슈 생성 또는 기존 이슈 확인
2. 브랜치 생성
3. 코드 작성 및 테스트
4. Pull Request 생성

## 라이선스

프로젝트 루트의 LICENSE 파일 참조

## 문의

이슈 트래커를 통해 버그 리포트나 기능 요청을 제출해주세요.
