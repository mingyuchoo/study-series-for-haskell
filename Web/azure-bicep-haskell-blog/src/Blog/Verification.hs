-- | 이메일 인증 대기 상태(가입 전)와 그 저장소 추상.
--
-- 회원가입은 두 단계다: 입력값으로 코드를 발송하면 'PendingSignup' 으로 대기하고,
-- 올바른 코드가 들어와 검증되면 비로소 실제 사용자가 만들어진다. 비밀번호는
-- 대기 단계부터 해시만, 코드도 해시('pendingCodeHash')만 보관한다.
module Blog.Verification
  ( PendingSignup (..)
  , VerificationStore (..)
  , CodeCheck (..)
  , checkCode
  ) where

import Data.Text (Text)
import Data.Time (UTCTime)

-- | 인증을 기다리는 가입 요청.
data PendingSignup = PendingSignup
  { pendingEmail        :: Text
  , pendingName         :: Text
  , pendingPasswordHash :: Text
    -- ^ bcrypt 해시(평문 아님).
  , pendingCodeHash     :: Text
    -- ^ 코드의 HMAC 해시(평문 아님).
  , pendingExpiresAt    :: UTCTime
    -- ^ 이 시각 이후엔 무효.
  , pendingAttempts     :: Int
    -- ^ 누적 오답 횟수.
  }
  deriving stock (Show, Eq)

-- | 대기 인증 저장소 연산 모음.
data VerificationStore = VerificationStore
  { storePending  :: PendingSignup -> IO ()
    -- ^ 이메일을 키로 대기 항목을 저장(같은 이메일이면 새 코드로 교체, 시도수 0).
  , getPending    :: Text -> IO (Maybe PendingSignup)
    -- ^ 이메일로 대기 항목 조회. 없으면 'Nothing'.
  , bumpAttempts  :: Text -> IO ()
    -- ^ 오답 1회를 누적한다.
  , deletePending :: Text -> IO ()
    -- ^ 대기 항목 삭제(성공·만료·초과 시).
  }

-- | 코드 검증 판정 결과.
data CodeCheck = Valid | Expired | TooManyAttempts | WrongCode
  deriving stock (Eq, Show)

-- | 대기 항목에 대해 만료·시도횟수·코드(해시) 일치를 판정한다(순수).
--
-- IO(조회·삭제·시도 누적)와 분리해 규칙만 담으므로 단독으로 테스트할 수 있다.
-- 입력은 사용자가 넣은 코드의 해시('pendingCodeHash' 와 같은 방식으로 만든 값)다.
checkCode :: UTCTime -> Int -> Text -> PendingSignup -> CodeCheck
checkCode now maxAttempts enteredHash p
  | pendingExpiresAt p < now = Expired
  | pendingAttempts p >= maxAttempts = TooManyAttempts
  | enteredHash /= pendingCodeHash p = WrongCode
  | otherwise = Valid
