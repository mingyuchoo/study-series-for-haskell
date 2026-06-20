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

-- | 애플리케이션 진입점 - 모든 계층 조합
startApp :: IO ()
startApp = do
  -- 설정 로드
  let config = defaultConfig

  -- 데이터베이스 초기화
  putStrLn "데이터베이스를 초기화합니다..."
  conn <- initializeDatabase

  -- 저장소 어댑터 생성
  let repository = createUserRepositoryAdapter conn

  -- 샘플 데이터 삽입 (설정에 따라)
  if appEnableSampleData config
    then insertSampleData repository
    else putStrLn "샘플 데이터 생성을 건너뜁니다."

  -- 웹 서버 시작
  putStrLn $ "서버를 포트 " ++ show (appPort config) ++ "에서 시작합니다..."
  startWebServer repository
