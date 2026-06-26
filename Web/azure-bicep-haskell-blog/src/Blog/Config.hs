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
-- @DATABASE_URL@이 없으면 'Left'로 실패를 명시한다.
--
-- 서명 마스터 키(@PREVIEW_SECRET@)는 __기본적으로 필수__다(fail-closed). 미설정
-- 시에는 리포지토리에 공개된 개발용 기본키로만 동작할 수 있는데, 그 키를 아는
-- 누구나 세션 쿠키를 위조해 계정을 탈취할 수 있으므로, 운영에서 조용히 취약해지지
-- 않도록 기동을 거부한다. 로컬 개발에서 그 기본키 사용을 의도한다면
-- @ALLOW_INSECURE_SECRET=1@ 로 __명시적으로__ 허용해야 하며, 그 경우에만
-- 'configInsecureKey' 가 참이 되어 'Main' 이 크게 경고한다.
loadConfig :: IO (Either String AppConfig)
loadConfig = do
  mPort <- lookupEnv "PORT"
  mUrl <- lookupEnv "DATABASE_URL"
  mKey <- lookupEnv "PREVIEW_SECRET"
  mAllowInsecure <- lookupEnv "ALLOW_INSECURE_SECRET"
  mAcsConn <- lookupEnv "ACS_CONNECTION_STRING"
  mAcsSender <- lookupEnv "ACS_SENDER_ADDRESS"
  let port = fromMaybe 8080 (mPort >>= readMaybe)
      allowInsecure = maybe False truthy mAllowInsecure
      -- 연결 문자열과 발신자 주소가 모두 있을 때만 ACS 발송을 활성화한다.
      acs = (,) <$> (T.pack <$> mAcsConn) <*> (T.pack <$> mAcsSender)
      mkCfg key insecure url = AppConfig port (BS8.pack url) key insecure acs
  pure $ case mUrl of
    Nothing -> Left "환경 변수 DATABASE_URL이 설정되지 않았습니다."
    Just url -> case mKey of
      Just k -> Right (mkCfg (BS8.pack k) False url)
      Nothing
        | allowInsecure -> Right (mkCfg "dev-insecure-secret-key" True url)
        | otherwise ->
            Left
              "PREVIEW_SECRET 미설정: 운영 배포는 서명 마스터 키 PREVIEW_SECRET 를 반드시 설정하세요. \
              \로컬 개발이라면 ALLOW_INSECURE_SECRET=1 로 개발용 기본키 사용을 명시적으로 허용해야 합니다."
  where
    -- 흔한 참 값 표기를 너그럽게 받아들인다.
    truthy s = T.toLower (T.strip (T.pack s)) `elem` ["1", "true", "yes", "on"]
