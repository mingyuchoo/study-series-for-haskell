# financial-validator

Haskell의 타입 안전성을 활용한 금융 거래 검증 시스템.

## 프로젝트 구조

```
financial-validator/
├── app/
│   └── Main.hs          -- 진입점, 테스트 데이터 및 거래 처리
├── src/
│   ├── Types.hs         -- 핵심 데이터 타입 (Transaction, Account, USD, KRW)
│   ├── Validation.hs    -- 거래 검증 파이프라인
│   └── Settlement.hs    -- 정산 리포트 및 분석
├── test/
│   └── Spec.hs
├── package.yaml
└── stack.yaml
```

## 주요 기능

- **타입 안전 통화**: `USD`, `KRW` newtype으로 통화 혼합을 컴파일 타임에 방지
- **거래 검증 파이프라인**: 금액, 잔액, 일일 한도, 계좌 상태 검증
- **정산 리포트**: 거래 건수, 승인/거절 통계, 총 거래량, 거절 사유 분석
- **계좌 관리**: 승인된 거래 후 계좌 잔액 갱신

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
| time | 시간 처리 |
| text | 텍스트 처리 |
| containers | 컨테이너 자료구조 |

## 사용된 GHC 확장

- `DataKinds`, `GADTs`, `KindSignatures`, `StandaloneKindSignatures`, `TypeApplications`, `ExplicitForAll`
