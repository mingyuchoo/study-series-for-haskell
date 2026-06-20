{-# LANGUAGE FlexibleInstances #-}

module Lib
    ( someFunc
    ) where

import           Control.Monad.IO.Class (MonadIO, liftIO)

-- ---------------------------------------------------
-- 1. 인터페이스(Capability) 정의 - Typeclass 사용
-- ---------------------------------------------------
class (Monad m) => MonadLogger m where
  logMsg :: String -> m ()

class (Monad m) => MonadDB m where
  fetchUser :: Int -> m String

-- ---------------------------------------------------
-- 2. 비즈니스 로직 작성
-- 구체적인 모나드(m)가 무엇인지는 모르지만,
-- 로깅과 DB 기능이 있다는 제약조건만 겁니다.
-- ---------------------------------------------------
program :: (MonadLogger m, MonadDB m) => m ()
program = do
  logMsg "Starting Tagless Final app..."
  user <- fetchUser 42
  logMsg $ "User found: " ++ user

-- ---------------------------------------------------
-- 3. 인터프리터 (구체적인 구현체 - IO용)
-- ---------------------------------------------------
newtype ProductionM a = ProductionM { runProd :: IO a }
     deriving (Applicative, Functor, Monad, MonadIO)

instance MonadLogger ProductionM where
  logMsg msg = liftIO $ putStrLn $ "[PROD LOG] " ++ msg

instance MonadDB ProductionM where
  fetchUser uid = liftIO $ return $ "User#" ++ show uid

-- ---------------------------------------------------
-- 4. 인터프리터 (테스트용 - 가짜 구현체)
-- IO 없이 순수한 상태로 테스트 가능
-- ---------------------------------------------------
instance MonadLogger (Either String) where
  logMsg _ = Right () -- 로그는 무시

instance MonadDB (Either String) where
  fetchUser 0   = Left "User not found"
  fetchUser uid = Right $ "TestUser" ++ show uid

-- ---------------------------------------------------
-- 5. 실행
-- ---------------------------------------------------
someFunc :: IO ()
someFunc = runProd program
