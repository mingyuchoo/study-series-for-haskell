module Infrastructure.Config.AppConfig
  ( AppConfig (..)
  , defaultConfig
  ) where

-- | 애플리케이션 설정
data AppConfig = AppConfig
  { appPort             :: Int
  , appDatabasePath     :: String
  , appEnableSampleData :: Bool
  }
  deriving (Show)

-- | 기본 설정
defaultConfig :: AppConfig
defaultConfig =
  AppConfig
    { appPort = 8000
    , appDatabasePath = "users.db"
    , appEnableSampleData = True
    }
