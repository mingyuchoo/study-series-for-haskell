module Lib
    ( App
    , AppF (..)
    , getUser
    , logMsg
    , program
    , runApp
    , someFunc
    ) where

import           Control.Monad.Free

-- ----------------------------------------------
-- 1. 언어(DSL) 정의 - Functor여야 함
-- 'next'는 다음으로 실행할 작업을 의미합니다.
-- ----------------------------------------------
data AppF next = LogMsg String next
               | GetUser Int (String -> next)
     deriving (Functor)

-- ----------------------------------------------
-- 2. Free Monad 타입 별칭
-- ----------------------------------------------
type App = Free AppF

-- ----------------------------------------------
-- 3. 스마트 생성자 (Smart Constructors)
-- 사용자가 DSL을 쉽게 쓰도록 돕는 도우미 함수들
-- ----------------------------------------------
logMsg :: String -> App ()
logMsg msg = liftF (LogMsg msg ())

getUser :: Int -> App String
getUser uid = liftF (GetUser uid id)

-- ----------------------------------------------
-- 4. 비즈니스 로직 작성
-- 실제 수행 코드는 없고, 수행할 작업의 순서(데이터)만 생성합니다.
-- ----------------------------------------------
program :: App ()
program = do
  logMsg "Starting Free Monad app..."
  user <- getUser 99
  logMsg $ "Got user: " ++ user

-- ----------------------------------------------
-- 5. 인터프리터 (Natural Transformation to IO)
-- 데이터를 보고 실제로 어떻게 수행할지 정의합니다.
-- ----------------------------------------------
runApp :: App a -> IO a
runApp (Pure a) = return a
runApp (Free (LogMsg msg next)) = do
  putStrLn $ "[FreeLog] " ++ msg
  runApp next
runApp (Free (GetUser uid next)) = do
  putStrLn "Querying DB..."
  let user = "User_" ++ show uid
  runApp (next user)

-- ----------------------------------------------
-- 6. 실행
-- ----------------------------------------------
someFunc :: IO ()
someFunc = runApp program
