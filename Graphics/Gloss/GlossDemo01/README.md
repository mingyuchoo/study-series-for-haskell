# GlossDemo01

Gloss 라이브러리를 사용한 기본 2D 그래픽스 예제.

## 프로젝트 구조

```
GlossDemo01/
├── app/
│   └── Main.hs      -- 진입점
├── src/
│   └── Lib.hs       -- Gloss 그래픽스 코드
├── test/
│   └── Spec.hs
├── package.yaml
└── stack.yaml
```

## 주요 기능

- **정적 그래픽스**: `display` 함수를 사용하여 정적 이미지 렌더링
- **윈도우 설정**: "My Window" 제목, 400x400 크기
- **렌더링**: 반지름 80의 원을 흰색 배경 위에 표시

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
