# geometry

ASCII 아트로 삼각형 패턴을 그리는 프로그램.

## 프로젝트 구조

```
geometry/
├── app/
│   └── Main.hs      -- 진입점
├── src/
│   └── Lib.hs       -- 삼각형 그리기 함수들
├── test/
│   └── Spec.hs
├── Makefile
├── package.yaml
└── stack.yaml
```

## 주요 기능

- **정삼각형 패턴**: `triangle1`, `triangle2`, `triangle3` 등 다양한 재귀 방식으로 삼각형 생성
- **역삼각형 패턴**: `upsideDownTriangle1`, `upsideDownTriangle2`, `upsideDownTriangle3`
- **다양한 구현**: case 표현식, 가드, 패턴 매칭 등 여러 스타일 비교

## 설치 및 실행 방법

```bash
# 빌드
stack build

# 실행
stack run

# 테스트 (watch 모드)
stack test --file-watch
```

## 주요 의존성

| 패키지 | 용도 |
|--------|------|
| base | 기본 라이브러리 |
| containers | 컨테이너 자료구조 |
| flow | 함수 파이핑 (`<\|` 연산자) |
| parallel | 병렬 처리 |
