# E2E 테스트 시나리오 문서

## 개요

- **문서 버전**: 1.0
- **최종 갱신일**: 2026-02-07
- **커버리지 요약**: 엔드포인트 17개 / 시나리오 32개

---

## 1. 인증 (Authentication)

### TC-001: 회원가입 페이지 접근

- **카테고리**: 정상
- **관련 요구사항**: REQ-F002
- **사전 조건**: 미로그인 상태
- **테스트 단계**:
  1. GET /auth/register 접근
  2. 회원가입 폼 표시 확인
- **기대 결과**: 이름, 이메일, 비밀번호 입력 폼이 표시됨
- **코드 근거**: [src/Handler/Auth.hs:12-15](src/Handler/Auth.hs#L12-L15)

### TC-002: 정상 회원가입

- **카테고리**: 정상
- **관련 요구사항**: REQ-F002
- **사전 조건**: 미로그인 상태, 미등록 이메일
- **테스트 단계**:
  1. GET /auth/register 접근
  2. 유효한 이름/이메일/비밀번호 입력
  3. 가입 버튼 클릭 (POST /auth/register)
- **기대 결과**:
  - 홈 페이지(/)로 리다이렉트
  - "회원가입이 완료되었습니다." 메시지 표시
  - 세션에 userId, userName 저장
- **코드 근거**: [src/Handler/Auth.hs:18-42](src/Handler/Auth.hs#L18-L42)

### TC-003: 중복 이메일로 회원가입 시도

- **카테고리**: 예외
- **관련 요구사항**: REQ-F002
- **사전 조건**: 이미 등록된 이메일 존재
- **테스트 단계**:
  1. GET /auth/register 접근
  2. 이미 등록된 이메일로 회원가입 시도
  3. POST /auth/register 제출
- **기대 결과**:
  - 회원가입 페이지로 리다이렉트
  - "이미 등록된 이메일입니다." 메시지 표시
- **코드 근거**: [src/Handler/Auth.hs:26-29](src/Handler/Auth.hs#L26-L29)

### TC-004: 로그인 페이지 접근

- **카테고리**: 정상
- **관련 요구사항**: REQ-F002
- **사전 조건**: 미로그인 상태
- **테스트 단계**:
  1. GET /auth/login 접근
  2. 로그인 폼 표시 확인
- **기대 결과**: 이메일, 비밀번호 입력 폼이 표시됨
- **코드 근거**: [src/Handler/Auth.hs:44-48](src/Handler/Auth.hs#L44-L48)

### TC-005: 정상 로그인

- **카테고리**: 정상
- **관련 요구사항**: REQ-F002
- **사전 조건**: 가입된 사용자 계정 존재
- **테스트 단계**:
  1. GET /auth/login 접근
  2. 올바른 이메일/비밀번호 입력
  3. 로그인 버튼 클릭 (POST /auth/login)
- **기대 결과**:
  - 홈 페이지(/)로 리다이렉트
  - "로그인되었습니다." 메시지 표시
  - 세션에 userId, userName 저장
- **코드 근거**: [src/Handler/Auth.hs:51-70](src/Handler/Auth.hs#L51-L70)

### TC-006: 잘못된 이메일로 로그인 시도

- **카테고리**: 예외
- **관련 요구사항**: REQ-F002
- **사전 조건**: 미로그인 상태
- **테스트 단계**:
  1. GET /auth/login 접근
  2. 미등록 이메일 입력
  3. POST /auth/login 제출
- **기대 결과**:
  - 로그인 페이지로 리다이렉트
  - "이메일 또는 비밀번호가 올바르지 않습니다." 메시지 표시
- **코드 근거**: [src/Handler/Auth.hs:57-60](src/Handler/Auth.hs#L57-L60)

### TC-007: 잘못된 비밀번호로 로그인 시도

- **카테고리**: 예외
- **관련 요구사항**: REQ-F002
- **사전 조건**: 가입된 사용자 계정 존재
- **테스트 단계**:
  1. GET /auth/login 접근
  2. 올바른 이메일, 잘못된 비밀번호 입력
  3. POST /auth/login 제출
- **기대 결과**:
  - 로그인 페이지로 리다이렉트
  - "이메일 또는 비밀번호가 올바르지 않습니다." 메시지 표시
- **코드 근거**: [src/Handler/Auth.hs:67-70](src/Handler/Auth.hs#L67-L70)

### TC-008: 로그아웃

- **카테고리**: 정상
- **관련 요구사항**: REQ-F002
- **사전 조건**: 로그인 상태
- **테스트 단계**:
  1. POST /auth/logout 호출
- **기대 결과**:
  - 홈 페이지(/)로 리다이렉트
  - "로그아웃되었습니다." 메시지 표시
  - 세션에서 userId, userName 삭제
- **코드 근거**: [src/Handler/Auth.hs:73-78](src/Handler/Auth.hs#L73-L78)

---

## 2. 홈 (Home)

### TC-009: 홈 페이지 접근

- **카테고리**: 정상
- **관련 요구사항**: REQ-F001
- **사전 조건**: 없음
- **테스트 단계**:
  1. GET / 접근
- **기대 결과**:
  - 최신 포스트 최대 10개 표시
  - 포스트별 작성자 정보 표시
- **코드 근거**: [src/Handler/Home.hs:11-18](src/Handler/Home.hs#L11-L18)

---

## 3. 포스트 (Post) - HTML

### TC-010: 포스트 목록 조회

- **카테고리**: 정상
- **관련 요구사항**: REQ-F003
- **사전 조건**: 없음
- **테스트 단계**:
  1. GET /posts 접근
- **기대 결과**:
  - 전체 포스트 목록 표시
  - 각 포스트의 제목, 작성자 정보 표시
- **코드 근거**: [src/Handler/Post.hs:13-20](src/Handler/Post.hs#L13-L20)

### TC-011: 포스트 작성 페이지 접근 (로그인 상태)

- **카테고리**: 정상
- **관련 요구사항**: REQ-F003
- **사전 조건**: 로그인 상태
- **테스트 단계**:
  1. GET /posts/new 접근
- **기대 결과**: 제목, 내용 입력 폼이 표시됨
- **코드 근거**: [src/Handler/Post.hs:23-29](src/Handler/Post.hs#L23-L29)

### TC-012: 포스트 작성 페이지 접근 (미로그인 상태)

- **카테고리**: 보안
- **관련 요구사항**: REQ-F003
- **사전 조건**: 미로그인 상태
- **테스트 단계**:
  1. GET /posts/new 접근
- **기대 결과**: 인증 오류 또는 로그인 페이지로 리다이렉트
- **코드 근거**: [src/Handler/Post.hs:25](src/Handler/Post.hs#L25) (`requireAuthId`)

### TC-013: 정상 포스트 작성

- **카테고리**: 정상
- **관련 요구사항**: REQ-F003
- **사전 조건**: 로그인 상태
- **테스트 단계**:
  1. GET /posts/new 접근
  2. 제목, 내용 입력
  3. POST /posts/new 제출
- **기대 결과**:
  - 생성된 포스트 상세 페이지로 리다이렉트
  - "포스트가 작성되었습니다." 메시지 표시
- **코드 근거**: [src/Handler/Post.hs:32-39](src/Handler/Post.hs#L32-L39)

### TC-014: 포스트 상세 조회

- **카테고리**: 정상
- **관련 요구사항**: REQ-F003
- **사전 조건**: 해당 포스트 존재
- **테스트 단계**:
  1. GET /posts/detail/:postId 접근
- **기대 결과**:
  - 포스트 제목, 내용, 작성자 표시
  - 댓글 목록 표시
- **코드 근거**: [src/Handler/Post.hs:42-55](src/Handler/Post.hs#L42-L55)

### TC-015: 존재하지 않는 포스트 조회

- **카테고리**: 예외
- **관련 요구사항**: REQ-F003
- **사전 조건**: 없음
- **테스트 단계**:
  1. 존재하지 않는 postId로 GET /posts/detail/:postId 접근
- **기대 결과**: 404 Not Found 응답
- **코드 근거**: [src/Handler/Post.hs:46](src/Handler/Post.hs#L46)

### TC-016: 본인 포스트 수정 페이지 접근

- **카테고리**: 정상
- **관련 요구사항**: REQ-F003
- **사전 조건**: 로그인 상태, 본인이 작성한 포스트 존재
- **테스트 단계**:
  1. GET /posts/edit/:postId 접근
- **기대 결과**: 기존 제목/내용이 채워진 수정 폼 표시
- **코드 근거**: [src/Handler/Post.hs:58-71](src/Handler/Post.hs#L58-L71)

### TC-017: 타인 포스트 수정 페이지 접근 시도

- **카테고리**: 보안
- **관련 요구사항**: REQ-F003
- **사전 조건**: 로그인 상태, 타인이 작성한 포스트 존재
- **테스트 단계**:
  1. 타인의 postId로 GET /posts/edit/:postId 접근
- **기대 결과**: 403 Permission Denied ("본인의 포스트만 수정할 수 있습니다.")
- **코드 근거**: [src/Handler/Post.hs:65-66](src/Handler/Post.hs#L65-L66)

### TC-018: 본인 포스트 수정

- **카테고리**: 정상
- **관련 요구사항**: REQ-F003
- **사전 조건**: 로그인 상태, 본인이 작성한 포스트 존재
- **테스트 단계**:
  1. GET /posts/edit/:postId 접근
  2. 제목/내용 수정
  3. POST /posts/edit/:postId 제출
- **기대 결과**:
  - 포스트 상세 페이지로 리다이렉트
  - "포스트가 수정되었습니다." 메시지 표시
- **코드 근거**: [src/Handler/Post.hs:74-88](src/Handler/Post.hs#L74-L88)

### TC-019: 본인 포스트 삭제

- **카테고리**: 정상
- **관련 요구사항**: REQ-F003
- **사전 조건**: 로그인 상태, 본인이 작성한 포스트 존재
- **테스트 단계**:
  1. POST /posts/delete/:postId 호출
- **기대 결과**:
  - 포스트 목록 페이지로 리다이렉트
  - "포스트가 삭제되었습니다." 메시지 표시
  - 연관 댓글도 함께 삭제
- **코드 근거**: [src/Handler/Post.hs:91-103](src/Handler/Post.hs#L91-L103)

### TC-020: 타인 포스트 삭제 시도

- **카테고리**: 보안
- **관련 요구사항**: REQ-F003
- **사전 조건**: 로그인 상태, 타인이 작성한 포스트 존재
- **테스트 단계**:
  1. 타인의 postId로 POST /posts/delete/:postId 호출
- **기대 결과**: 403 Permission Denied ("본인의 포스트만 삭제할 수 있습니다.")
- **코드 근거**: [src/Handler/Post.hs:98-99](src/Handler/Post.hs#L98-L99)

---

## 4. 댓글 (Comment) - HTML

### TC-021: 댓글 작성

- **카테고리**: 정상
- **관련 요구사항**: REQ-F004
- **사전 조건**: 로그인 상태, 포스트 존재
- **테스트 단계**:
  1. 포스트 상세 페이지에서 댓글 내용 입력
  2. POST /posts/detail/:postId/comments 제출
- **기대 결과**:
  - 포스트 상세 페이지로 리다이렉트
  - "댓글이 작성되었습니다." 메시지 표시
- **코드 근거**: [src/Handler/Comment.hs:10-16](src/Handler/Comment.hs#L10-L16)

### TC-022: 미인증 상태 댓글 작성 시도

- **카테고리**: 보안
- **관련 요구사항**: REQ-F004
- **사전 조건**: 미로그인 상태
- **테스트 단계**:
  1. POST /posts/detail/:postId/comments 호출
- **기대 결과**: 인증 오류 또는 로그인 페이지로 리다이렉트
- **코드 근거**: [src/Handler/Comment.hs:12](src/Handler/Comment.hs#L12) (`requireAuthId`)

### TC-023: 본인 댓글 삭제

- **카테고리**: 정상
- **관련 요구사항**: REQ-F004
- **사전 조건**: 로그인 상태, 본인이 작성한 댓글 존재
- **테스트 단계**:
  1. POST /comments/delete/:commentId 호출
- **기대 결과**:
  - 해당 포스트 상세 페이지로 리다이렉트
  - "댓글이 삭제되었습니다." 메시지 표시
- **코드 근거**: [src/Handler/Comment.hs:19-30](src/Handler/Comment.hs#L19-L30)

### TC-024: 타인 댓글 삭제 시도

- **카테고리**: 보안
- **관련 요구사항**: REQ-F004
- **사전 조건**: 로그인 상태, 타인이 작성한 댓글 존재
- **테스트 단계**:
  1. 타인의 commentId로 POST /comments/delete/:commentId 호출
- **기대 결과**: 403 Permission Denied ("댓글을 삭제할 권한이 없습니다.")
- **코드 근거**: [src/Handler/Comment.hs:29](src/Handler/Comment.hs#L29)

---

## 5. 포스트 API (Post API)

### TC-025: API 포스트 목록 조회

- **카테고리**: 정상
- **관련 요구사항**: REQ-F003
- **사전 조건**: 없음
- **테스트 단계**:
  1. GET /api/posts 호출
- **기대 결과**:
  - JSON 형식으로 포스트 목록 반환
  - `{ "posts": [...] }` 구조
- **코드 근거**: [src/Handler/ApiPost.hs:14-17](src/Handler/ApiPost.hs#L14-L17)

### TC-026: API 포스트 생성

- **카테고리**: 정상
- **관련 요구사항**: REQ-F003
- **사전 조건**: 로그인 상태
- **테스트 단계**:
  1. POST /api/posts 호출 (body: `{"title": "...", "content": "..."}`)
- **기대 결과**:
  - `{"id": ..., "message": "생성 완료"}` 반환
- **코드 근거**: [src/Handler/ApiPost.hs:20-28](src/Handler/ApiPost.hs#L20-L28)

### TC-027: API 포스트 생성 시 필수 필드 누락

- **카테고리**: 예외
- **관련 요구사항**: REQ-F003
- **사전 조건**: 로그인 상태
- **테스트 단계**:
  1. POST /api/posts 호출 (title 또는 content 누락)
- **기대 결과**: 400 Invalid Args ("title과 content가 필요합니다.")
- **코드 근거**: [src/Handler/ApiPost.hs:25](src/Handler/ApiPost.hs#L25)

### TC-028: API 포스트 상세 조회

- **카테고리**: 정상
- **관련 요구사항**: REQ-F003
- **사전 조건**: 해당 포스트 존재
- **테스트 단계**:
  1. GET /api/posts/:postId 호출
- **기대 결과**: 포스트 상세 정보 JSON 반환
- **코드 근거**: [src/Handler/ApiPost.hs:31-36](src/Handler/ApiPost.hs#L31-L36)

### TC-029: API 포스트 수정 (본인)

- **카테고리**: 정상
- **관련 요구사항**: REQ-F003
- **사전 조건**: 로그인 상태, 본인 포스트 존재
- **테스트 단계**:
  1. PUT /api/posts/:postId 호출 (body: `{"title": "...", "content": "..."}`)
- **기대 결과**: `{"message": "수정 완료"}` 반환
- **코드 근거**: [src/Handler/ApiPost.hs:39-54](src/Handler/ApiPost.hs#L39-L54)

### TC-030: API 포스트 삭제 (본인)

- **카테고리**: 정상
- **관련 요구사항**: REQ-F003
- **사전 조건**: 로그인 상태, 본인 포스트 존재
- **테스트 단계**:
  1. DELETE /api/posts/:postId 호출
- **기대 결과**: `{"message": "삭제 완료"}` 반환
- **코드 근거**: [src/Handler/ApiPost.hs:57-68](src/Handler/ApiPost.hs#L57-L68)

---

## 6. 댓글 API (Comment API)

### TC-031: API 댓글 목록 조회

- **카테고리**: 정상
- **관련 요구사항**: REQ-F004
- **사전 조건**: 포스트 존재
- **테스트 단계**:
  1. GET /api/posts/:postId/comments 호출
- **기대 결과**:
  - JSON 형식으로 댓글 목록 반환
  - `{ "comments": [...] }` 구조
- **코드 근거**: [src/Handler/ApiComment.hs:14-17](src/Handler/ApiComment.hs#L14-L17)

### TC-032: API 댓글 생성

- **카테고리**: 정상
- **관련 요구사항**: REQ-F004
- **사전 조건**: 로그인 상태, 포스트 존재
- **테스트 단계**:
  1. POST /api/posts/:postId/comments 호출 (body: `{"content": "..."}`)
- **기대 결과**: `{"id": ..., "message": "생성 완료"}` 반환
- **코드 근거**: [src/Handler/ApiComment.hs:20-28](src/Handler/ApiComment.hs#L20-L28)

---

## 코드-시나리오 추적 매트릭스

| 소스 파일 | 라인 범위 | 관련 시나리오 |
|-----------|-----------|---------------|
| [src/Handler/Auth.hs](src/Handler/Auth.hs) | 12-15 | TC-001 |
| [src/Handler/Auth.hs](src/Handler/Auth.hs) | 18-42 | TC-002, TC-003 |
| [src/Handler/Auth.hs](src/Handler/Auth.hs) | 44-48 | TC-004 |
| [src/Handler/Auth.hs](src/Handler/Auth.hs) | 51-70 | TC-005, TC-006, TC-007 |
| [src/Handler/Auth.hs](src/Handler/Auth.hs) | 73-78 | TC-008 |
| [src/Handler/Home.hs](src/Handler/Home.hs) | 11-18 | TC-009 |
| [src/Handler/Post.hs](src/Handler/Post.hs) | 13-20 | TC-010 |
| [src/Handler/Post.hs](src/Handler/Post.hs) | 23-29 | TC-011, TC-012 |
| [src/Handler/Post.hs](src/Handler/Post.hs) | 32-39 | TC-013 |
| [src/Handler/Post.hs](src/Handler/Post.hs) | 42-55 | TC-014, TC-015 |
| [src/Handler/Post.hs](src/Handler/Post.hs) | 58-71 | TC-016, TC-017 |
| [src/Handler/Post.hs](src/Handler/Post.hs) | 74-88 | TC-018 |
| [src/Handler/Post.hs](src/Handler/Post.hs) | 91-103 | TC-019, TC-020 |
| [src/Handler/Comment.hs](src/Handler/Comment.hs) | 10-16 | TC-021, TC-022 |
| [src/Handler/Comment.hs](src/Handler/Comment.hs) | 19-30 | TC-023, TC-024 |
| [src/Handler/ApiPost.hs](src/Handler/ApiPost.hs) | 14-17 | TC-025 |
| [src/Handler/ApiPost.hs](src/Handler/ApiPost.hs) | 20-28 | TC-026, TC-027 |
| [src/Handler/ApiPost.hs](src/Handler/ApiPost.hs) | 31-36 | TC-028 |
| [src/Handler/ApiPost.hs](src/Handler/ApiPost.hs) | 39-68 | TC-029, TC-030 |
| [src/Handler/ApiComment.hs](src/Handler/ApiComment.hs) | 14-17 | TC-031 |
| [src/Handler/ApiComment.hs](src/Handler/ApiComment.hs) | 20-28 | TC-032 |

---

## 시나리오 통계 요약

| 카테고리 | 시나리오 수 |
|----------|-------------|
| 정상     | 20          |
| 예외     | 5           |
| 보안     | 7           |
| **합계** | **32**      |
