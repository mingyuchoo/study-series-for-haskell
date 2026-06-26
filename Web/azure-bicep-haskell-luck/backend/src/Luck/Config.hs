-- | 환경변수에서 애플리케이션 설정을 읽어온다.
--
--   운영 모드(@APP_ENV=production@)에서는 보안에 중요한 환경변수(JWT_SECRET,
--   DATABASE_URL)가 없으면 안전한 기본값으로 조용히 폴백하지 않고 기동을 거부한다
--   (알려진 기본 시크릿으로 토큰이 위조되는 사고를 막는다).
module Luck.Config
    ( Config (..)
    , loadConfig
    ) where

import           Data.ByteString       (ByteString)
import qualified Data.ByteString.Char8 as BS
import           Data.Char             (toLower)
import           Data.Text             (Text)
import qualified Data.Text             as T
import           System.Environment    (lookupEnv)
import           System.Exit           (exitFailure)
import           System.IO             (hPutStrLn, stderr)
import           Text.Read             (readMaybe)

-- | 런타임 설정.
data Config = Config
  { cfgDbUrl          :: ByteString
  -- ^ PostgreSQL libpq 접속 문자열
  , cfgJwtSecret      :: ByteString
  -- ^ JWT 서명용 비밀키
  , cfgPort           :: Int
  -- ^ HTTP 리슨 포트
  , cfgAllowedOrigins :: [ByteString]
  -- ^ CORS 허용 오리진 화이트리스트 (비어 있으면 모든 오리진 허용 — 개발용)
  , cfgAdminEmails    :: [Text]
  -- ^ 관리자 이메일(소문자). 설정되면 first-user 자동 관리자 규칙은 비활성화된다.
  , cfgIsProduction   :: Bool
  -- ^ 운영 모드 여부 (HSTS, fail-fast 등에 사용)
  }

-- | 환경변수에서 설정을 읽는다. 운영 모드에서 필수값이 없으면 기동을 중단한다.
loadConfig :: IO Config
loadConfig = do
  isProd <- isProduction
  dbUrl <- requireOrDev isProd "DATABASE_URL" devDbUrl
  secret <- requireOrDev isProd "JWT_SECRET" devSecret
  port <- maybe 8080 id . (>>= readMaybe) <$> lookupEnv "PORT"
  origins <- envList "ALLOWED_ORIGINS"
  admins <- envList "ADMIN_EMAILS"
  pure
    Config
      { cfgDbUrl = BS.pack dbUrl
      , cfgJwtSecret = BS.pack secret
      , cfgPort = port
      , cfgAllowedOrigins = map (BS.pack . T.unpack) origins
      , cfgAdminEmails = map T.toLower admins
      , cfgIsProduction = isProd
      }
  where
    devDbUrl = "postgresql://luck:luck@localhost:5432/luck"
    devSecret = "dev-only-insecure-secret-change-me-in-production"

-- | @APP_ENV@ 가 "production"(대소문자 무관)인지.
isProduction :: IO Bool
isProduction = do
  v <- lookupEnv "APP_ENV"
  pure (fmap (map toLower) v == Just "production")

-- | 환경변수가 있으면 그 값을, 없으면:
--   운영 모드면 치명적 오류로 기동 중단, 개발 모드면 경고 후 기본값 사용.
requireOrDev :: Bool -> String -> String -> IO String
requireOrDev isProd name devDefault = do
  mv <- lookupEnv name
  case mv of
    Just v | not (null v) -> pure v
    _
      | isProd -> do
          hPutStrLn
            stderr
            ("[FATAL] 운영 모드(APP_ENV=production)에서 필수 환경변수 '"
               <> name
               <> "' 가 설정되지 않았습니다. 기동을 중단합니다.")
          exitFailure
      | otherwise -> do
          hPutStrLn
            stderr
            ("[warn] '"
               <> name
               <> "' 미설정 — 개발용 기본값을 사용합니다. 운영 배포 전 반드시 설정하세요.")
          pure devDefault

-- | 콤마로 구분된 환경변수를 trim된 비어있지 않은 항목 리스트로 읽는다.
envList :: String -> IO [Text]
envList name = do
  mv <- lookupEnv name
  pure $ case mv of
    Nothing -> []
    Just s  -> filter (not . T.null) (map T.strip (T.splitOn "," (T.pack s)))
