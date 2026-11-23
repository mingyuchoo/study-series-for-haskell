module Lib
  ( User (..)
  , startApp
  ) where

import Adapters.Repository.UserRepositoryAdapter
import Adapters.Web.UserWebAdapter

import Domain.UserModel

import Infrastructure.Config.AppConfig
import Infrastructure.Database.Connection
import Infrastructure.Database.SampleData

startApp :: IO ()
startApp = do
  let config = defaultConfig

  putStrLn "데이터베이스를 초기화합니다..."
  conn <- initializeDatabase

  let repository = createUserRepositoryAdapter conn

  if appEnableSampleData config
    then insertSampleData repository
    else putStrLn "샘플 데이터 생성을 건너뜁니다."

  putStrLn $ "서버를 포트 " ++ show (appPort config) ++ "에서 시작합니다..."
  startWebServer repository
