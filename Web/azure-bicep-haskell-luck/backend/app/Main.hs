-- | 실행 진입점: 설정을 읽고 DB 풀과 JWT를 준비한 뒤 Warp로 서버를 띄운다.
module Main
    ( main
    ) where

import           Data.Proxy               (Proxy (..))
import           Luck.Api                 (api)
import           Luck.App                 (AppEnv (..), runAppM)
import           Luck.Auth                (jwtSettingsFromSecret)
import           Luck.Config              (Config (..), loadConfig)
import           Luck.DB                  (initSchema, newConnPool)
import           Luck.Repository.User     (promoteAdmins)
import           Luck.Server              (server)
import           Luck.Web.Middleware
    ( corsMiddleware
    , newRateLimiter
    , rateLimit
    , securityHeaders
    )
import           Network.Wai              (Application)
import           Network.Wai.Handler.Warp (run)
import           Servant
import           System.IO
    ( BufferMode (LineBuffering)
    , hSetBuffering
    , stderr
    , stdout
    )
import           Servant.Auth.Server
    ( CookieSettings
    , JWTSettings
    , defaultCookieSettings
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

main :: IO ()
main = do
  -- 컨테이너/파이프 환경에서 stdout 은 기본이 블록 버퍼링이라 로그가 즉시 보이지
  -- 않는다. 라인 버퍼링으로 바꿔 putStrLn(가입 인증번호 등)이 줄 단위로 바로 출력되게 한다.
  hSetBuffering stdout LineBuffering
  hSetBuffering stderr LineBuffering
  cfg <- loadConfig
  pool <- newConnPool (cfgDbUrl cfg)
  initSchema pool
  promoteAdmins pool (cfgAdminEmails cfg)
  limiter <- newRateLimiter
  let jwtCfg = jwtSettingsFromSecret (cfgJwtSecret cfg)
      env = AppEnv pool jwtCfg cfg
      -- 바깥부터: rate limit → 보안 헤더 → CORS → 앱
      middleware =
        rateLimit limiter
          . securityHeaders (cfgIsProduction cfg)
          . corsMiddleware (cfgAllowedOrigins cfg)
  putStrLn ("Luck backend listening on :" <> show (cfgPort cfg))
  run (cfgPort cfg) (middleware (mkApp env))
