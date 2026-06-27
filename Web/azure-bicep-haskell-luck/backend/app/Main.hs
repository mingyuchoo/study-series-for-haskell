-- | 실행 진입점: 설정을 읽고 DB 풀과 JWT를 준비한 뒤 Warp로 서버를 띄운다.
module Main
    ( main
    ) where

import           Luck.Api                 (api)
import           Luck.App                 (AppEnv (..), runAppM)
import           Luck.Auth                (jwtSettingsFromSecret)
import           Luck.Config              (Config (..), loadConfig)
import           Luck.DB                  (initSchema, newConnPool)
import           Luck.Email               (newEmailSender)
import           Luck.Repository.User     (promoteAdmins)
import           Luck.Server              (server)
import           Luck.Web.Middleware
    ( corsMiddleware
    , newRateLimiter
    , rateLimit
    , securityHeaders
    )
import           Network.HTTP.Types       (status200)
import           Network.Wai
    ( pathInfo
    , responseFile
    )
import           Network.Wai.Application.Static
    ( defaultFileServerSettings
    , staticApp
    )
import           Network.Wai.Handler.Warp (run)
import           Servant
import           System.Environment       (lookupEnv)
import           System.FilePath          ((</>))
import           System.IO
    ( BufferMode (LineBuffering)
    , hSetBuffering
    , stderr
    , stdout
    )
import           WaiAppStatic.Types
    ( ss404Handler
    , ssIndices
    , unsafeToPiece
    )
import           Servant.Auth.Server
    ( CookieSettings
    , JWTSettings
    , defaultCookieSettings
    )

-- | 보호 라우트에 필요한 Servant 컨텍스트.
type Ctx = '[CookieSettings, JWTSettings]

-- | Servant API 애플리케이션 (@/api@ 하위 라우트만 처리).
mkApi :: AppEnv -> Application
mkApi env =
  serveWithContext api ctx $
    hoistServerWithContext api (Proxy @Ctx) (runAppM env) server
  where
    ctx :: Context Ctx
    ctx = defaultCookieSettings :. envJwt env :. EmptyContext

-- | 빌드된 SPA(프런트엔드) 정적 파일을 서빙하는 애플리케이션.
--   디렉터리에 없는 경로는 @index.html@ 로 폴백해 클라이언트 사이드 라우팅을 살린다.
spaApp :: FilePath -> Application
spaApp dir = staticApp settings
  where
    settings =
      (defaultFileServerSettings dir)
        { ssIndices = [unsafeToPiece "index.html"]
        , ss404Handler = Just indexFallback
        }
    indexFallback _req send =
      send $
        responseFile
          status200
          [("Content-Type", "text/html; charset=utf-8")]
          (dir </> "index.html")
          Nothing

-- | 전체 WAI 애플리케이션: @/api/*@ 는 Servant, 그 외 경로는 정적 SPA.
mkApp :: AppEnv -> FilePath -> Application
mkApp env staticDir req send =
  case pathInfo req of
    ("api" : _) -> mkApi env req send
    _           -> spaApp staticDir req send

main :: IO ()
main = do
  -- 컨테이너/파이프 환경에서 stdout 은 기본이 블록 버퍼링이라 로그가 즉시 보이지
  -- 않는다. 라인 버퍼링으로 바꿔 putStrLn(가입 인증번호 등)이 줄 단위로 바로 출력되게 한다.
  hSetBuffering stdout LineBuffering
  hSetBuffering stderr LineBuffering
  cfg <- loadConfig
  -- 빌드된 SPA 정적 파일 경로. 컨테이너에서는 STATIC_DIR 로 주입하며 기본값은 "static".
  staticDir <- maybe "static" id <$> lookupEnv "STATIC_DIR"
  pool <- newConnPool (cfgDbUrl cfg)
  initSchema pool
  promoteAdmins pool (cfgAdminEmails cfg)
  emailSender <- newEmailSender (cfgAcsConnString cfg) (cfgAcsSender cfg)
  limiter <- newRateLimiter
  let jwtCfg = jwtSettingsFromSecret (cfgJwtSecret cfg)
      env = AppEnv pool jwtCfg cfg emailSender
      -- 바깥부터: rate limit → 보안 헤더 → CORS → 앱
      middleware =
        rateLimit limiter
          . securityHeaders (cfgIsProduction cfg)
          . corsMiddleware (cfgAllowedOrigins cfg)
  putStrLn ("Luck backend listening on :" <> show (cfgPort cfg))
  run (cfgPort cfg) (middleware (mkApp env staticDir))
