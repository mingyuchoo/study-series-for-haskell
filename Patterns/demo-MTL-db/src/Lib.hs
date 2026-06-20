{-# LANGUAGE GeneralizedNewtypeDeriving #-}

module Lib
    ( someFunc
    ) where

import           Control.Monad.Reader

-- ----------------------------------------------
-- 1. 환경(Env) 정의: DB 커넥션이나 로거 설정 등이 들어갑니다.
-- ----------------------------------------------
data AppEnv = AppEnv
  { dbConnString :: String
  , logLevel     :: Int
  }

-- ----------------------------------------------
-- 2. App Monad 정의: ReaderT와 IO를 감쌉니다.
-- ----------------------------------------------
newtype App a = App {unApp :: ReaderT AppEnv IO a}
  deriving (Applicative, Functor, Monad, MonadIO, MonadReader AppEnv)

-- ----------------------------------------------
-- 3. 비즈니스 로직 (구체적인 구현)
-- Env에서 설정을 읽어와서 IO 작업을 수행합니다.
-- ----------------------------------------------
logMessage :: String -> App ()
logMessage msg = do
  env <- ask
  liftIO $ putStrLn $ "[Log Level " ++ show (logLevel env) ++ "] " ++ msg

getUser :: Int -> App String
getUser userId = do
  env <- ask
  liftIO $ putStrLn $ "Connecting to DB: " ++ dbConnString env
  return $ "User" ++ show userId

-- ----------------------------------------------
-- 4. 메인 로직 조합
-- ----------------------------------------------
program :: App ()
program = do
  logMessage "Starting application..."
  user <- getUser 101
  logMessage $ "Fetched: " ++ user

-- ----------------------------------------------
-- 5. 실행 (Interpreter 역할)
-- ----------------------------------------------
someFunc :: IO ()
someFunc = do
  let env = AppEnv "postgres://localhost:5432" 1
  runReaderT (unApp program) env
