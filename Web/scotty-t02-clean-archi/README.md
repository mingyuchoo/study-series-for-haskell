# scotty-t02-clean-archi

Scotty 웹 프레임워크와 Redis를 사용한 URL 단축 서비스 (클린 아키텍처 적용)

## 프로젝트 구조

```
src/
├── Domain/                          # 도메인 계층
│   ├── Entity/Url.hs                #   - Url 엔티티 및 검증 로직
│   └── Repository/UrlRepository.hs  #   - UrlRepository 타입 클래스 인터페이스
├── Application/UseCase/             # 애플리케이션 계층
│   ├── ShortenUrl.hs                #   - URL 단축 유스케이스
│   ├── RetrieveUrl.hs               #   - URL 조회 유스케이스
│   └── ListUrls.hs                  #   - URL 목록 유스케이스
├── Infrastructure/Repository/       # 인프라 계층
│   ├── InMemoryUrlRepository.hs     #   - IORef 기반 인메모리 구현
│   └── RedisUrlRepository.hs        #   - Redis 기반 영속 구현
├── Adapters/Web/                    # 어댑터 계층
│   ├── Controller/UrlController.hs  #   - HTTP 핸들러 (Scotty)
│   └── View/UrlView.hs             #   - HTML 뷰 (Blaze)
└── Lib.hs                           # Scotty 앱 초기화 및 라우팅
```

## 아키텍처

클린 아키텍처 4계층 구조를 따릅니다.

- **Domain** - 핵심 비즈니스 엔티티(`Url`)와 리포지토리 인터페이스(`UrlRepository` 타입 클래스)
- **Application** - 유스케이스 (단축, 조회, 목록)
- **Infrastructure** - 리포지토리 구현체 (InMemory, Redis)
- **Adapters** - 웹 컨트롤러와 HTML 뷰

자세한 설명은 [docs/CLEAN_ARCHITECTURE.md](docs/CLEAN_ARCHITECTURE.md)를 참고하세요.

## API 엔드포인트

| 메서드 | 경로 | 설명 |
|--------|------|------|
| GET | `/` | 홈 페이지 (URL 목록 + 입력 폼) |
| POST | `/` | 새 URL 단축 |
| GET | `/:n` | 단축 URL로 원본 URL 리다이렉트 |

## 기술 스택

- **웹 프레임워크**: Scotty
- **템플릿**: Blaze HTML
- **영속성**: Redis (hedis 라이브러리)
- **빌드 도구**: Stack (resolver lts-24.20)
- **컨테이너**: Docker + Docker Compose

## 실행 방법

### Docker Compose (권장)

```bash
# Redis + 앱 함께 실행
make docker-compose-up

# 로그 확인
make docker-compose-logs

# 종료
make docker-compose-down
```

앱은 `http://localhost:8000`에서 접근 가능합니다.

### 로컬 실행

Redis가 로컬에서 실행 중이어야 합니다.

```bash
# 빌드
make build

# 실행
make run
```

### 기타 Make 명령

```bash
make test          # 테스트 실행
make coverage      # 테스트 커버리지
make watch         # 파일 변경 감시 모드
make ghcid         # ghcid 개발 모드
make format        # 코드 포맷팅 (stylish-haskell)
make redis-cli     # Redis CLI 접속
make redis-keys    # Redis 키 목록 조회
make redis-flushall # Redis 데이터 전체 삭제
```

## References

- <https://www.stackbuilders.com/tutorials/haskell/getting-started-with-haskell-projects-using-scotty/>
