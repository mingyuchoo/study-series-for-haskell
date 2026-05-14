# servant-t00-init

Servant 웹 프레임워크를 사용한 기본 REST API 프로젝트입니다.

## 기술 스택

- **GHC2024** / **Stack** (resolver: lts-24.40)
- **Servant** - 타입 레벨 Web API 프레임워크
- **Warp** - 고성능 HTTP 서버
- **Aeson** - JSON 직렬화/역직렬화
- **hspec-wai** - WAI 애플리케이션 테스트

## 프로젝트 구조

```
.
├── app/Main.hs          # 애플리케이션 진입점
├── src/Lib.hs           # API 타입 정의, 서버 핸들러
├── test/Spec.hs         # API 테스트 (hspec-wai)
├── package.yaml         # 패키지 설정
├── stack.yaml           # Stack 설정 (Docker 포함)
├── Makefile             # 빌드/테스트/실행 자동화
└── docker/              # Docker 관련 파일
```

## 프로젝트 생성 방법

```bash
stack new <project-name> mingyuchoo/new-template
```

## 빌드

```bash
stack build
# 또는
stack build --fast -j4 --ghc-options "-j16 +RTS -A256m -RTS"
```

## 테스트

```bash
stack test --fast
# Watch 모드
stack test --fast --file-watch --watch-all
# 커버리지 포함
stack test --coverage --fast --file-watch --watch-all --haddock
# ghcid 사용
ghcid --command "stack ghci test/Spec.hs"
```

## 실행

```bash
stack run
```

서버가 **포트 4000**에서 시작됩니다.

## API 엔드포인트

| Method | Path     | 설명                  | 응답 타입    |
|--------|----------|-----------------------|-------------|
| GET    | `/users` | 전체 사용자 목록 조회  | `[User]`    |
| GET    | `/isaac` | Isaac Newton 정보 조회 | `User`      |
| GET    | `/albert`| Albert Einstein 정보 조회 | `User`  |

```bash
# 전체 사용자 조회
curl http://localhost:4000/users

# 개별 사용자 조회
curl http://localhost:4000/isaac
curl http://localhost:4000/albert
```

## Makefile 타겟

```bash
make build          # 빌드
make test           # 테스트
make run            # 실행
make watch-test     # 테스트 Watch 모드
make coverage       # 테스트 커버리지
make docker-build   # Docker 이미지 빌드
make docker-run     # Docker 컨테이너 실행
```

전체 타겟 목록은 `Makefile`을 참고하세요.

## References

- <https://docs.servant.dev/en/stable/tutorial/index.html>
- <https://www.aosabook.org/en/posa/warp.html>
- <https://www.yesodweb.com/book/web-application-interface>
