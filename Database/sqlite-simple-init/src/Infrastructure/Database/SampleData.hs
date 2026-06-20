{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Infrastructure.Database.SampleData
  ( insertSampleData
  ) where

import Application.UserService (UserService (..))

import Control.Exception (catch)

import Database.SQLite.Simple (SQLError)

-- | 샘플 데이터 삽입
insertSampleData :: (UserService a) => a -> IO ()
insertSampleData userService = do
  putStrLn "샘플 데이터를 생성합니다..."

  -- 샘플 사용자 생성 (이메일 중복 에러는 무시)
  _ <- createUserSafe "홍길동" "hong@example.com" "password123"
  _ <- createUserSafe "김철수" "kim@example.com" "password456"
  _ <- createUserSafe "이영희" "lee@example.com" "password789"
  _ <- createUserSafe "박민수" "park@example.com" "password000"
  _ <- createUserSafe "정수진" "jung@example.com" "password111"

  putStrLn "샘플 데이터 생성 완료!"
  where
    createUserSafe name email password =
      (createUser userService name email password >> return ())
        `catch` (\(_ :: SQLError) -> return ())
