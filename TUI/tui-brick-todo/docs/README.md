# 개발 문서

- [아키텍처와 ADT 상태 머신](ARCHITECTURE.md)
- [키 바인딩](KEY_BINDINGS.md)
- [프로젝트 사용법과 배포](../README.md)
- [상태 머신 설계](superpowers/specs/2026-11-19-adt-workflow-design.md)
- [리팩토링 계획과 검증 기록](superpowers/plans/2026-11-19-adt-workflow.md)

## 실행과 테스트

```bash
stack build
stack exec tto-exe
stack test --fast
```

`packages/domain`은 순수 도메인 모델을, `packages/application`은 순수 상태 전이와 저장소 포트를, `packages/terminal/src`는 Brick·SQLite·파일 접근을 담당합니다. 진입점은 `apps/tto/Main.hs`입니다.

## 기능 확장

새 업무 규칙은 domain에, 새 이벤트와 작업 절차는 application의 ADT와 전이 함수에 추가합니다. 부수 효과가 필요하면 application의 포트를 정의하고 terminal의 infrastructure에서 구현합니다. UI 입력을 업무 이벤트로 변환하는 코드는 `UI.Events`에 추가합니다.

순수 모델과 전이는 각 패키지의 `test/Spec.hs`에서, DB와 UI 경계는 루트 `test/`에서 검증합니다. Haskell 포맷은 Fourmolu를 사용합니다.

## 사용자 설정

`~/.config/tto/settings.yaml`의 `language`를 `ko` 또는 `en`으로 설정합니다. 같은 디렉터리에 키 바인딩과 메시지 YAML 파일을 둘 수 있습니다. 예시는 루트 `config/`에 있습니다.
