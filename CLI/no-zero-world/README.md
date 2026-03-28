# no-zero-world

0이 없는 세계의 숫자 체계를 구현한 알고리즘 문제 풀이.

## 프로젝트 구조

```
no-zero-world/
├── app/
│   └── Main.hs      -- 진입점
├── src/
│   └── Lib.hs       -- 숫자 변환 로직
├── test/
│   └── Spec.hs
├── Makefile
├── package.yaml
└── stack.yaml
```

## 주요 기능

- **문제**: 0이 존재하지 않는 세계에서 숫자에 1을 더한 결과를 구함
- **해법**: 1을 더한 후, 결과에 포함된 '0'을 모두 '1'로 대체
- **예시**: `9949999 + 1 = 9950000` → `9951111`

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
