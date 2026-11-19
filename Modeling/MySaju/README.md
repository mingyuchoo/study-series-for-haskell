# MySaju

## 개발 스크립트

Stack, Fourmolu, HLint가 PATH에 있어야 합니다. Stack을 설치한 후 필요한 도구를 설치합니다.

```sh
stack install fourmolu hlint
```

프로젝트 루트에서 다음 명령을 실행합니다.

```sh
./scripts/run.sh
```

PowerShell 7.3 이상에서는 다음 명령을 사용합니다.

```powershell
pwsh -File .\scripts\run.ps1
```

두 스크립트 모두 다른 디렉터리에서 경로를 지정하여 실행할 수 있습니다.
`fourmolu.yaml`에 따라 `src/`, `app/`, `test/`의 Haskell 파일과 `Setup.hs`를 직접
포맷팅한 뒤 HLint 검사, `stack build`, `stack test`, `stack exec MySaju-exe`를 순서대로
실행합니다. 도구가 없거나 어느 단계든 실패하면 즉시 종료하며 실패 종료 코드를 반환합니다.
스크립트에 전달한 인자는 최종 실행 프로그램에 그대로 전달합니다.
