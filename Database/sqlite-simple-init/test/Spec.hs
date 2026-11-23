{-# LANGUAGE PatternGuards #-}

module Main
    where

import           Control.Monad                           (unless, when)
import           Data.Maybe                              (isJust, isNothing)
import           System.Exit                             (exitFailure)
import           Application.UserService                 (UserService (..))
import           Domain.UserModel                        (User (..))
import           Database.SQLite.Simple                 (withConnection)
import           Infrastructure.Database.Connection    (createTables)
import           Infrastructure.Repository.UserRepository (UserRepository (..))
import           System.IO (BufferMode (NoBuffering), hSetBuffering, stdout)

-- |
main :: IO ()
main = withConnection ":memory:" $ \conn -> do
    hSetBuffering stdout NoBuffering
    createTables conn
    let repo = UserRepository conn

    -- 1) Initially empty
    users0 <- getAllUsers repo
    assertEq "Initial users should be empty" 0 (length users0)

    -- 2) Create a user
    user1 <- createUser repo "John Doe" "john@example.com" "password123"
    assertBool "Created user should have an id" (isJust (userId user1))
    assertEq "Created user name" "John Doe" (userName user1)
    assertEq "Created user email" "john@example.com" (userEmail user1)
    -- 3) getAllUsers should now have 1
    users1 <- getAllUsers repo
    assertEq "getAllUsers after one create" 1 (length users1)

    -- 4) getUserById should return the same user, then update and delete it
    let
        handleFetched m uid1
          | Just fetched <- m = do
                assertEq "Fetched user id" (Just uid1) (userId fetched)
                assertEq "Fetched user name" (userName user1) (userName fetched)
                assertEq "Fetched user email" (userEmail user1) (userEmail fetched)
          | otherwise = failTest "getUserById returned Nothing for existing user"

        handleUpdated m
          | Just updated <- m = do
                assertEq "Updated user name" "John Updated" (userName updated)
                assertEq "Updated user email" "john.updated@example.com" (userEmail updated)
          | otherwise = failTest "User not found after update"

        handleUserId m
          | Just uid1 <- m = do
                mFetched1 <- getUserById repo uid1
                handleFetched mFetched1 uid1

                -- 5) Update user
                updOk <- updateUser repo uid1 "John Updated" "john.updated@example.com" "newpassword123"
                assertBool "updateUser should return True" updOk

                mUpdated <- getUserById repo uid1
                handleUpdated mUpdated

                -- 6) Delete user
                delOk <- deleteUser repo uid1
                assertBool "deleteUser should return True" delOk

                mDeleted <- getUserById repo uid1
                assertBool "User should be gone after delete" (isNothing mDeleted)
          | otherwise = failTest "Created user has no id"

    handleUserId (userId user1)

    putStrLn "All tests passed."
--------------------------------------------------------------------------------
-- Minimal assertion helpers (avoid adding new test dependencies)

assertEq :: (Eq a, Show a) => String -> a -> a -> IO ()
assertEq msg expected actual =
    when (actual /= expected) $ do
        putStrLn ("ASSERTION FAILED: " <> msg)
        putStrLn ("  expected: " <> show expected)
        putStrLn ("  but got : " <> show actual)
        exitFailure

assertBool :: String -> Bool -> IO ()
assertBool msg cond =
    unless cond $ do
        putStrLn ("ASSERTION FAILED: " <> msg)
        exitFailure

failTest :: String -> IO ()
failTest msg = do
    putStrLn ("TEST FAILED: " <> msg)
    exitFailure
