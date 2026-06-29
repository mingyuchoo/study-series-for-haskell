-- | 도메인 에러. 웹/DB를 모르는 가장 안쪽 계층 — 모든 계층이 의존할 수 있다.
--   HTTP 상태코드로의 변환은 'Luck.Web.Error' 가 담당한다.
module Luck.Error
    ( DomainError (..)
    ) where

import           Data.Text (Text)

-- | 비즈니스 규칙 위반/실패를 표현한다 (Servant 'ServerError' 와 무관).
data DomainError
  = -- | 입력값 검증 실패 (→ 400)
    ValidationError Text
  | -- | 이미 가입된 이메일 (→ 409)
    EmailTaken
  | -- | 이메일/비밀번호 불일치 (→ 401)
    InvalidCredentials
  | -- | 권한 없음 (→ 403)
    Forbidden Text
  | -- | 리소스 충돌, 예: key 중복 (→ 409)
    Conflict Text
  | -- | 리소스를 찾을 수 없음 (→ 404)
    NotFound Text
  | -- | 시도 횟수 초과 (→ 429)
    TooManyAttempts Text
  | -- | JWT 발급 실패 (→ 500)
    TokenFailure
  | -- | 기타 내부 오류 (→ 500)
    InternalError Text
  deriving stock (Show, Eq)
