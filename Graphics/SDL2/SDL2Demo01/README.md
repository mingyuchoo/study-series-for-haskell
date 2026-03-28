# SDL2Demo01

SDL2를 사용한 기본 게임 개발 예제.

## 프로젝트 구조

```
SDL2Demo01/
├── app/
│   └── Main.hs      -- 진입점
├── src/
│   └── Lib.hs       -- SDL2 렌더링 및 게임 루프
├── test/
│   └── Spec.hs
├── package.yaml
└── stack.yaml
```

## 주요 기능

- **SDL2 초기화**: 윈도우 및 렌더러 생성
- **렌더링**: 파란색 배경 위에 빨간색 사각형 (100, 100) 위치, 50x50 크기
- **게임 루프**: `appLoop` 함수를 통한 렌더링 및 이벤트 처리
- **리소스 정리**: 렌더러, 윈도우 파괴 및 SDL 종료

## 설치 및 실행 방법

```bash
# SDL2 시스템 라이브러리 설치 필요
# Ubuntu: sudo apt-get install libsdl2-dev
# macOS: brew install sdl2

# 빌드
stack build

# 실행
stack run
```

## 주요 의존성

| 패키지 | 용도 |
|--------|------|
| base | 기본 라이브러리 |
| sdl2 | SDL2 바인딩 |
| linear | 벡터 수학 (V2, V4, Point) |
| text | 텍스트 처리 |
