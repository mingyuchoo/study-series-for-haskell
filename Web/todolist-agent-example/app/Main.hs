module Main (main) where

import Network.Wai.Handler.Warp (run)
import Shared.Config (AppConfig (..), loadConfig)
import Shared.Database (DatabaseConfig (..))
import Todo.Interface.HTTP.Server (mkApplication, mkProductionHandlerEnv)

main :: IO ()
main = do
    config <- loadConfig
    let dbConfig = DatabaseConfig (databaseUrl config)
    env <- mkProductionHandlerEnv dbConfig
    putStrLn ("TodoList listening on port " <> show (appPort config))
    run (appPort config) (mkApplication env)
