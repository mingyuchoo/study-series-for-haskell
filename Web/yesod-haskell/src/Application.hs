{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell   #-}

-- | [REQ-F001] 애플리케이션 초기화 및 디스패치
module Application
  where

import Foundation
import Model (migrateAll)
import Settings

import Control.Monad.Logger (runStderrLoggingT)
import Database.Persist.Sqlite (createSqlitePool, runMigration, runSqlPool)
import Network.Wai.Handler.Warp (run)
import Yesod.Core

-- Handler 모듈 import (mkYesodDispatch가 핸들러 함수를 참조하므로 전체 import 필요)

import Handler.ApiComment
import Handler.ApiPost
import Handler.Auth
import Handler.Comment
import Handler.Home
import Handler.Post

mkYesodDispatch "App" resourcesApp

-- | 애플리케이션 실행
appMain :: IO ()
appMain = do
  let settings = defaultSettings
  pool <-
    runStderrLoggingT $
      createSqlitePool (appDatabasePath settings) 10
  runStderrLoggingT $ runSqlPool (runMigration migrateAll) pool
  let app =
        App
          { appSettings = settings
          , appConnectionPool = pool
          }
  putStrLn $ "서버가 포트 " ++ show (appPort settings) ++ "에서 실행 중입니다..."
  waiApp <- toWaiApp app
  run (appPort settings) waiApp
