{-# LANGUAGE OverloadedStrings #-}

-- | [REQ-F001] 애플리케이션 설정
module Settings where

import Data.Text (Text)

-- | 애플리케이션 설정 값
data AppSettings = AppSettings
    { appPort         :: Int
    , appDatabasePath :: Text
    }

-- | 기본 설정
defaultSettings :: AppSettings
defaultSettings = AppSettings
    { appPort         = 3000
    , appDatabasePath = "blog.sqlite3"
    }
