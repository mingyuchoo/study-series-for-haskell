# 요구사항 관리 문서

| REQ-ID   | 구분 | 제목                          | 상태   | 영향 파일                                                    | 등록일     |
|----------|------|-------------------------------|--------|--------------------------------------------------------------|------------|
| REQ-F001 | F    | 프로젝트 초기 설정             | 완료   | demo-haskell.cabal, cabal.project, src/Foundation.hs, src/Import.hs, src/Model.hs, src/Settings.hs, src/Application.hs, app/Main.hs | 2026-02-06 |
| REQ-F002 | F    | 사용자 인증 (회원가입/로그인)  | 완료   | src/Handler/Auth.hs, src/Service/AuthService.hs, templates/auth/ | 2026-02-06 |
| REQ-F003 | F    | 포스트 CRUD                   | 완료   | src/Handler/Post.hs, src/Handler/ApiPost.hs, src/Service/PostService.hs, templates/post/ | 2026-02-06 |
| REQ-F004 | F    | 댓글 CRUD                     | 완료   | src/Handler/Comment.hs, src/Handler/ApiComment.hs, src/Service/CommentService.hs | 2026-02-06 |
| REQ-N001 | N    | README.md 작성                | 완료   | README.md                                                    | 2026-02-06 |
| REQ-N002 | N    | .gitignore 파일 생성           | 완료   | .gitignore                                                   | 2026-02-06 |
| REQ-T001 | N    | 단위/통합 테스트 구현          | 완료   | demo-haskell.cabal, test/Spec.hs, test/TestFoundation.hs, test/Unit/*.hs, test/Integration/*.hs | 2026-02-06 |
| REQ-N003 | N    | README.md 현행화 (테스트 반영) | 완료   | README.md                                                    | 2026-02-06 |
| REQ-N004 | N    | CLAUDE.md 테스트 규칙 추가     | 완료   | CLAUDE.md                                                    | 2026-02-07 |
| REQ-N005 | N    | E2E 테스트 시나리오 문서 자동생성 규칙 | 완료   | CLAUDE.md, docs/test-scenarios.md                            | 2026-02-07 |
| REQ-N006 | N    | requirements.md를 docs/로 이동       | 완료   | requirements.md → docs/requirements.md, CLAUDE.md            | 2026-02-07 |
| REQ-N007 | N    | E2E 테스트 시나리오 문서 생성         | 완료   | docs/test-scenarios.md                                       | 2026-02-07 |
| REQ-N008 | N    | 요구사항 추적성 주석 추가              | 완료   | src/**/*.hs, test/**/*.hs                                    | 2026-02-07 |
| REQ-N009 | N    | README.md 현행화 (프로젝트 구조)       | 완료   | README.md                                                    | 2026-02-07 |
| REQ-N010 | N    | 정적 분석(HLint) 문서화 및 실행         | 진행중 | README.md                                                    | 2026-02-07 |
