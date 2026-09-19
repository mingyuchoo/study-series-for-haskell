{-# LANGUAGE OverloadedStrings #-}

-- | api 실행 파일의 진입점입니다.
--
-- 설정은 환경 변수로만 받습니다. CLI와 같은 @TODO_DB@ 경로를 공유하므로 두 표면이
-- 같은 데이터를 봅니다. 동시 접근 안전성은 WAL 모드로 확보합니다
-- (@docs/incidents/INC-2026-001.md@).
--
-- 수신 주소는 루프백으로 고정하며 설정할 수 없습니다. 이 API에는 인증이 없으므로
-- 접근 경로 제한이 유일한 방어선입니다 (@docs/decisions/ADR-0004-web-surface.md@).
module Main (main) where

import Data.Maybe (fromMaybe)
import Network.Wai.Handler.Warp (defaultSettings, runSettings, setHost, setPort)
import System.Environment (lookupEnv)
import Text.Read (readMaybe)
import Todo.Api.Server (application)
import Todo.Store.Sqlite (openStore)

defaultPort :: Int
defaultPort = 8080

defaultDatabasePath :: FilePath
defaultDatabasePath = "todo.db"

main :: IO ()
main = do
  path <- fromMaybe defaultDatabasePath <$> lookupEnv "TODO_DB"
  rawPort <- lookupEnv "TODO_API_PORT"
  let port = fromMaybe defaultPort (rawPort >>= readMaybe)
      -- 루프백 고정입니다. 환경 변수로 노출하지 않는 것이 결정의 일부입니다.
      settings = setHost "127.0.0.1" (setPort port defaultSettings)
  conn <- openStore path
  putStrLn ("api listening on 127.0.0.1:" <> show port <> " using " <> path)
  runSettings settings (application conn)
