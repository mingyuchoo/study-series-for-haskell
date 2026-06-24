-- | 환경 변수에서 애플리케이션 설정을 읽는다.
module Blog.Config
  ( AppConfig (..)
  , loadConfig
  ) where

import Data.ByteString (ByteString)
import Data.ByteString.Char8 qualified as BS8
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Text qualified as T
import System.Environment (lookupEnv)
import Text.Read (readMaybe)

-- | 런타임 설정.
data AppConfig = AppConfig
  { configPort        :: Int
    -- ^ HTTP 리스닝 포트. 기본 8080 (ACA ingress targetPort와 일치).
  , configDatabaseUrl :: ByteString
    -- ^ libpq 연결 문자열. 예: postgresql://user:pw\@host:5432/db?sslmode=require
  , configSecretKey   :: ByteString
    -- ^ 서명 마스터 비밀. 여기서 용도별 서브키('Blog.Keys.deriveKeys')를
    --   파생해 미리보기 토큰과 세션 쿠키 서명에 도메인 분리해 쓴다.
  , configInsecureKey :: Bool
    -- ^ @PREVIEW_SECRET@ 미설정으로 개발용 기본키를 쓰는 중인가('Main'이 경고).
  , configAcs         :: Maybe (Text, Text)
    -- ^ @(ACS_CONNECTION_STRING, ACS_SENDER_ADDRESS)@. 둘 다 있으면 실제 이메일 발송,
    --   없으면 'Main' 이 로그 폴백('logEmailSender')을 쓴다.
  }

-- | 환경 변수에서 설정을 읽는다.
--
-- @DATABASE_URL@이 없으면 'Left'로 실패를 명시한다. @PREVIEW_SECRET@이 없으면
-- 개발용 기본키로 동작하되 'configInsecureKey' 로 그 사실을 노출한다(조용한
-- 프로덕션 미설정을 막기 위해 'Main' 이 이를 보고 경고한다).
loadConfig :: IO (Either String AppConfig)
loadConfig = do
  mPort <- lookupEnv "PORT"
  mUrl <- lookupEnv "DATABASE_URL"
  mKey <- lookupEnv "PREVIEW_SECRET"
  mAcsConn <- lookupEnv "ACS_CONNECTION_STRING"
  mAcsSender <- lookupEnv "ACS_SENDER_ADDRESS"
  let port = fromMaybe 8080 (mPort >>= readMaybe)
      key = maybe "dev-insecure-secret-key" BS8.pack mKey
      -- 연결 문자열과 발신자 주소가 모두 있을 때만 ACS 발송을 활성화한다.
      acs = (,) <$> (T.pack <$> mAcsConn) <*> (T.pack <$> mAcsSender)
  pure $ case mUrl of
    Nothing  -> Left "환경 변수 DATABASE_URL이 설정되지 않았습니다."
    Just url -> Right (AppConfig port (BS8.pack url) key (mKey == Nothing) acs)
