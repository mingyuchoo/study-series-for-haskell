-- | 애플리케이션 환경과 핸들러 모나드를 정의한다.
module Luck.App
    ( AppEnv (..)
    , AppM
    , runAppM
    ) where

import           Control.Monad.Reader       (ReaderT, runReaderT)
import           Data.Pool                  (Pool)
import           Database.PostgreSQL.Simple (Connection)
import           Luck.Config                (Config)
import           Luck.Email                 (EmailSender)
import           Servant                    (Handler)
import           Servant.Auth.Server        (JWTSettings)

-- | 핸들러가 공유하는 읽기 전용 환경.
data AppEnv = AppEnv
  { envPool   :: Pool Connection
  , envJwt    :: JWTSettings
  , envConfig :: Config
  , envEmail  :: EmailSender
  }

-- | 핸들러 모나드: 환경을 읽으며 Servant 'Handler' 위에서 동작한다.
type AppM = ReaderT AppEnv Handler

-- | 'AppM' 을 'Handler' 로 변환 (Servant hoist 용).
runAppM :: AppEnv -> AppM a -> Handler a
runAppM env action = runReaderT action env
