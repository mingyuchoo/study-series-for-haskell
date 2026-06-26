-- | 실행 진입점: 설정을 읽고 DB 풀과 JWT를 준비한 뒤 Warp로 서버를 띄운다.
module Main (main) where

import Data.Proxy (Proxy (..))
import Luck.Api (API, api)
import Luck.App (AppEnv (..), runAppM)
import Luck.Config (Config (..), loadConfig)
import Luck.DB (initSchema, newConnPool)
import Luck.Server (server)
import Network.Wai (Application)
import Network.Wai.Handler.Warp (run)
import Network.Wai.Middleware.Cors
  ( CorsResourcePolicy (..)
  , cors
  , simpleCorsResourcePolicy
  )
import Servant
import Servant.Auth.Server
  ( CookieSettings
  , JWTSettings
  , defaultCookieSettings
  , defaultJWTSettings
  , fromSecret
  )

-- | 보호 라우트에 필요한 Servant 컨텍스트.
type Ctx = '[CookieSettings, JWTSettings]

-- | WAI 애플리케이션 구성.
mkApp :: AppEnv -> Application
mkApp env =
  serveWithContext api ctx $
    hoistServerWithContext api (Proxy @Ctx) (runAppM env) server
  where
    ctx :: Context Ctx
    ctx = defaultCookieSettings :. envJwt env :. EmptyContext

-- | 프런트엔드(다른 오리진)에서의 호출을 허용하는 CORS 미들웨어.
corsMiddleware :: Application -> Application
corsMiddleware = cors (const (Just policy))
  where
    policy =
      simpleCorsResourcePolicy
        { corsRequestHeaders = ["Authorization", "Content-Type"]
        , corsMethods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
        }

main :: IO ()
main = do
  cfg <- loadConfig
  pool <- newConnPool (cfgDbUrl cfg)
  initSchema pool
  let jwtCfg = defaultJWTSettings (fromSecret (cfgJwtSecret cfg))
      env = AppEnv pool jwtCfg cfg
  putStrLn ("Luck backend listening on :" <> show (cfgPort cfg))
  run (cfgPort cfg) (corsMiddleware (mkApp env))
