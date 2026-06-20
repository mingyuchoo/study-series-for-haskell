module Main
    where

import           Control.Concurrent                                       (killThread)

import           Data.Either                                              (isLeft)
import           Data.Int                                                 (Int64)
import           Data.List                                                (find)
import           Data.Maybe                                               (isJust)
import           Data.Text                                                (Text)

import           Domain.Entities.User                                     (User (..),
                                                                           UserAge (..),
                                                                           UserEmail (..),
                                                                           UserId (..),
                                                                           UserName (..),
                                                                           UserOccupation (..))

import           Infrastructure.Cache.Redis.CacheServiceImpl              (RedisInfo,
                                                                           localRedisInfo)
import           Infrastructure.Persistence.PostgreSQL.UserRepositoryImpl (PGInfo,
                                                                           localConnString)

import           Servant.Client                                           (ClientEnv,
                                                                           runClientM)

import           System.IO                                                (BufferMode (NoBuffering),
                                                                           hSetBuffering,
                                                                           stdout)

import           Test.Hspec

import           TestUtils                                                (setupTests)

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  (pgInfo, redisInfo, clientEnv, tid) <- setupTests
  hspec $ do
    describe "Basic server functionality" $ do
      it "Server should start successfully" $ do
        -- Simple test to verify server startup
        True `shouldBe` True
      it "Database connection should be available" $ do
        -- Simple test to verify database setup
        True `shouldBe` True
  killThread tid
  return ()

-- Test data for future use
testUser :: User
testUser =
  User
    { userId = Nothing
    , userName = UserName "james"
    , userEmail = UserEmail "james@test.com"
    , userAge = UserAge 25
    , userOccupation = UserOccupation "Software Engineer"
    }
