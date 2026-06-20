{-# LANGUAGE OverloadedStrings #-}

-- | [REQ-T001] 테스트 인프라 — 테스트용 App 생성 및 헬퍼
module TestFoundation
  where

import Application ()
import Foundation (App (..))
import Model (migrateAll)
import Settings (defaultSettings)

import Control.Monad.IO.Class (liftIO)
import Control.Monad.Logger (runNoLoggingT)
import Database.Persist.Sql (SqlPersistT, runSqlPool)
import Database.Persist.Sqlite (createSqlitePool, runMigration)
import Test.Hspec (Spec, SpecWith, before)
import Yesod.Test (TestApp, YesodExample, getTestYesod)

-- | 테스트용 App 생성 (in-memory SQLite, 풀 크기 1)
makeTestFoundation :: IO App
makeTestFoundation = do
  pool <- runNoLoggingT $ createSqlitePool ":memory:" 1
  runNoLoggingT $ runSqlPool (runMigration migrateAll) pool
  return
    App
      { appSettings = defaultSettings
      , appConnectionPool = pool
      }

-- | 테스트용 TestApp 생성
makeTestApp :: IO (TestApp App)
makeTestApp = do
  foundation <- makeTestFoundation
  return (foundation, id)

-- | hspec before 헬퍼 — 각 테스트마다 새로운 App 생성
withApp :: SpecWith (TestApp App) -> Spec
withApp = before makeTestApp

-- | YesodExample 내에서 DB 쿼리 실행
runTestDB :: SqlPersistT IO a -> YesodExample App a
runTestDB action = do
  app <- getTestYesod
  liftIO $ runSqlPool action (appConnectionPool app)
