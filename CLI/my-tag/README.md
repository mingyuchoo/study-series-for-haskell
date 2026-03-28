# my-tag

Parsec을 사용한 커스텀 태그 변환기.

## 프로젝트 구조

```
my-tag/
├── app/
│   └── Main.hs      -- 진입점
├── src/
│   └── Lib.hs       -- 파서 및 태그 변환 로직
├── test/
│   └── Spec.hs
├── Makefile
├── package.yaml
└── stack.yaml
```

## 주요 기능

- **파일 기반 변환**: `input.txt`에서 읽어 `output.tsx`로 출력
- **태그 파싱**: Parsec의 `string`, `manyTill`, `anyChar`, `try` 함수를 활용한 태그 파싱
- **변환 규칙**: `<제목>` 태그를 `<MainTitle>` 태그로 변환
- **오류 처리**: Parsec의 Either 타입으로 파싱 실패 처리

## 설치 및 실행 방법

```bash
# 빌드
stack build

# 실행
stack run

# 테스트
stack test
```

## 주요 의존성

| 패키지 | 용도 |
|--------|------|
| base | 기본 라이브러리 |
| parsec | 모나딕 파서 컴비네이터 |
