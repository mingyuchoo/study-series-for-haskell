module Infrastructure.Config.AppConfig
  ( AppConfig (..)
  , defaultConfig
  ) where

data AppConfig = AppConfig
  { appPort             :: Int
  , appDatabasePath     :: String
  , appEnableSampleData :: Bool
  }
  deriving (Show)

defaultConfig :: AppConfig
defaultConfig =
  AppConfig
    { appPort = 8000
    , appDatabasePath = "users.db"
    , appEnableSampleData = True
    }
