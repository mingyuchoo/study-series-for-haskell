# Contracts Index

Todo 앱의 표면과 저장 형식 중 외부가 의존하는 공개 약속을 관리합니다.

- API 계약: `api/README.md`
- 이벤트 계약: `events/README.md`
- 데이터 계약: `data/README.md`

## 현재 게시된 계약

| 계약 | 종류 | 소유 패키지 | 상태 |
|---|---|---|---|
| [Todo API v1](api/TODO-API-v1.md) | API | api | Active |
| [Todo Store v1](data/TODO-STORE-v1.md) | 데이터 | store | Active |

이벤트 계약은 아직 없습니다. 필요해지기 전에 만들지 않습니다.

## 계약 원칙

1. 계약은 구현보다 먼저 또는 같은 변경에서 갱신합니다.
2. 호환성을 깨는 변경에는 버전 전환과 폐기 계획이 필요합니다.
3. 오류 코드, 시간 제한, 재시도와 멱등성도 계약의 일부입니다.
4. 계약은 가능한 한 계약 테스트로 검증합니다. 문서만 있는 약속은 곧 어긋납니다.
5. 내부 표현을 편의를 위해 그대로 공개하지 않습니다. 도메인 타입과 전송 표현은 분리합니다.

원칙 5의 근거는 `../decisions/ADR-0003-api-boundary.md`에 있습니다.
