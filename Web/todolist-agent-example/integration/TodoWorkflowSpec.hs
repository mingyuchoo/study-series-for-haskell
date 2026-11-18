{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Exception (bracket)
import Data.Text qualified as Text
import Database.PostgreSQL.Simple (Only (..), close, query_)
import Shared.Database (DatabaseConfig (..), connectDatabase)
import System.Environment (lookupEnv)
import Test.Hspec (describe, hspec, it, pendingWith, shouldBe)

main :: IO ()
main = hspec $ describe "PostgreSQL integration" $ do
    it "connects and can execute SELECT 1" $ do
        maybeUrl <- lookupEnv "TEST_DATABASE_URL"
        case maybeUrl of
            Nothing -> pendingWith "Set TEST_DATABASE_URL to run PostgreSQL integration tests"
            Just url ->
                bracket
                    (connectDatabase (DatabaseConfig (Text.pack url)))
                    close
                    ( \conn -> do
                        rows <- query_ conn "SELECT 1" :: IO [Only Int]
                        rows `shouldBe` [Only 1]
                    )
