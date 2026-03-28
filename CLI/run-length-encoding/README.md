# run-length-encoding

Run-Length Encoding(RLE) 데이터 압축 알고리즘 구현.

## 프로젝트 구조

```
run-length-encoding/
├── app/
│   └── Main.hs      -- 진입점
├── src/
│   └── Lib.hs       -- 인코딩 로직
├── test/
│   └── Spec.hs
├── Makefile
├── package.yaml
└── stack.yaml
```

## 주요 기능

- **RLE 인코딩**: 연속된 동일 문자를 문자+횟수로 압축
- **예시**:
  - `""` → `""`
  - `"a"` → `"a1"`
  - `"aaaaabbbccccccddddddddd"` → `"a5b3c6d9"`

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
