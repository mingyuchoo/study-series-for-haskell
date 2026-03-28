# OpenGLDemo01

GLUT 바인딩을 사용한 기본 OpenGL 그래픽스 예제.

## 프로젝트 구조

```
OpenGLDemo01/
├── app/
│   └── Main.hs      -- 진입점
├── src/
│   └── Lib.hs       -- OpenGL 렌더링 코드
├── test/
│   └── Spec.hs
├── package.yaml
└── stack.yaml
```

## 주요 기능

- **OpenGL 초기화**: GLUT를 통한 윈도우 생성 및 디스플레이 콜백 설정
- **컬러 삼각형 렌더링**: `renderPrimitive Triangles`로 색상이 있는 삼각형 그리기
  - 꼭짓점 (0, 1, 0): 빨강
  - 꼭짓점 (-1, -1, 0): 초록
  - 꼭짓점 (1, -1, 0): 파랑
- **연속 렌더링**: `mainLoop`를 통한 인터랙티브 디스플레이

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
| GLUT | OpenGL Utility Toolkit 바인딩 |
