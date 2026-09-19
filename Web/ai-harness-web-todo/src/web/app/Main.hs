{-# LANGUAGE OverloadedStrings #-}

-- | web 실행 파일의 진입점입니다.
--
-- 설정은 환경 변수로만 받습니다. @TODO_DB@를 @cli@ 및 @api@와 공유하므로
-- 세 표면이 같은 데이터를 봅니다. 동시 접근 안전성은 WAL 모드로 확보합니다
-- (@docs/incidents/INC-2026-001.md@).
--
-- 수신 주소는 루프백으로 고정하며 설정할 수 없습니다. 이 표면에는 인증이 없으므로
-- 접근 경로 제한이 유일한 방어선입니다 (@docs/decisions/ADR-0004-web-surface.md@).
module Main (main) where

import Network.Wai.Handler.Warp (defaultSettings, runSettings, setHost, setPort)
import System.Environment (lookupEnv)
import Todo.Store.Sqlite (openStore)
import Todo.Web.Config (WebConfig (..), resolveConfig)
import Todo.Web.Server (application)

main :: IO ()
main = do
  config <- resolveConfig <$> lookupEnv "TODO_DB" <*> lookupEnv "TODO_WEB_PORT"
  let
    -- 루프백 고정입니다. 환경 변수로 노출하지 않는 것이 결정의 일부입니다.
    settings = setHost "127.0.0.1" (setPort (webPort config) defaultSettings)
  conn <- openStore (webDatabasePath config)
  putStrLn
    ( "web listening on 127.0.0.1:"
        <> show (webPort config)
        <> " using "
        <> webDatabasePath config
    )
  runSettings settings (application conn)
