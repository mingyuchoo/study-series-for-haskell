# GlossDemo02

Gloss 라이브러리를 사용한 애니메이션 예제.

## 프로젝트 구조

```
GlossDemo02/
├── app/
│   └── Main.hs      -- 진입점
├── src/
│   └── Lib.hs       -- 애니메이션 로직
├── test/
│   └── Spec.hs
├── package.yaml
└── stack.yaml
```

## 주요 기능

- **프레임 기반 애니메이션**: `animate` 함수를 사용한 시간 기반 애니메이션
- **회전 원**: 경과 시간에 따라 회전하는 원 (`Rotate (time * 30)`)
- **순수 함수형 애니메이션**: 상태가 시간 값 하나로만 표현됨

## 설치 및 실행 방법

```bash
# 빌드
stack build

# 실행
stack run
```

## 주요 의존성

| 패키지 | 용도 |
|--------|------|
| base | 기본 라이브러리 |
| gloss | 2D 그래픽스 라이브러리 |
