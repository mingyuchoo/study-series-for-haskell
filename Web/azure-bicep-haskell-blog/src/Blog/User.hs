-- | 사용자 도메인 타입과 저장소 추상.
--
-- 'PostStore' 와 같은 record-of-functions 패턴을 따른다. 비밀번호 해싱은
-- 도메인이 아니라 'Blog.Auth' 가 담당하므로, 여기서는 이미 해시된 값만 다룬다.
module Blog.User
  ( User (..)
  , NewUser (..)
  , UserError (..)
  , UserStore (..)
  , Theme (..)
  , renderTheme
  , parseTheme
  ) where

import Data.Text (Text)
import Data.Time (UTCTime)

-- | 사용자가 지정한 화면 테마. 계정에 저장되어 기기 간에 따라온다.
data Theme = Light | Dark
  deriving stock (Show, Eq)

-- | 저장·HTML @data-theme@ 표기로 직렬화한다.
renderTheme :: Theme -> Text
renderTheme Light = "light"
renderTheme Dark  = "dark"

-- | 저장값을 'Theme' 로 해석한다. 알 수 없는 값(과거 @system@ 등)은 'Light'.
parseTheme :: Text -> Theme
parseTheme "dark" = Dark
parseTheme _      = Light

-- | 저장된 사용자.
data User = User
  { userId           :: Int
  , userEmail        :: Text
  , userName         :: Text
    -- ^ 표시 이름.
  , userBio          :: Text
    -- ^ 자기소개(없으면 빈 문자열).
  , userPasswordHash :: Text
    -- ^ bcrypt 해시(평문 아님).
  , userCreatedAt    :: UTCTime
  , userTheme        :: Theme
    -- ^ 계정에 저장된 화면 테마.
  }
  deriving stock (Show, Eq)

-- | 아직 저장되지 않은 가입 입력값. 비밀번호는 __이미 해시된__ 값이다.
data NewUser = NewUser
  { newUserEmail        :: Text
  , newUserName         :: Text
  , newUserPasswordHash :: Text
  }
  deriving stock (Show, Eq)

-- | 사용자 저장 실패 사유.
data UserError -- | 이메일 유니크 제약 위반.
               = EmailTaken
               | OtherUserError Text
  deriving stock (Show, Eq)

-- | 사용자 저장소 연산 모음.
data UserStore = UserStore
  { userInsert         :: NewUser -> IO (Either UserError User)
    -- ^ 새 사용자 저장. 이메일 중복이면 'Left' 'EmailTaken'.
  , userByEmail        :: Text -> IO (Maybe User)
    -- ^ 이메일로 조회(로그인용). 없으면 'Nothing'.
  , userById           :: Int -> IO (Maybe User)
    -- ^ ID로 조회(세션 복원용). 없으면 'Nothing'.
  , userUpdateProfile  :: Int -> Text -> Text -> IO (Maybe User)
    -- ^ 표시 이름·자기소개를 갱신(프로필 수정). 없으면 'Nothing'.
  , userUpdatePassword :: Int -> Text -> IO (Maybe User)
    -- ^ 비밀번호 해시를 갱신한다(이미 해시된 값). 없으면 'Nothing'.
  , userUpdateTheme    :: Int -> Theme -> IO (Maybe User)
    -- ^ 계정 테마를 갱신한다. 없으면 'Nothing'.
  }
