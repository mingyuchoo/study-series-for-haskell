{-# LANGUAGE OverloadedStrings #-}

module Main where

import Data.Text (Text)
import Models.Contact (Contact(..), ContactId(..))
import Services.ContactRepository (loadContactsFromFile, saveContactsToFile)
import System.Directory (removeFile, doesFileExist)
import Control.Exception (try, IOException)

-- Test data
testContact1 :: Contact
testContact1 = Contact
    { contactId = ContactId 1
    , contactName = "홍길동"
    , contactPhone = Just "010-1234-5678"
    , contactEmail = Just "hong@example.com"
    , contactAddress = Just "서울시 강남구"
    }

testContact2 :: Contact
testContact2 = Contact
    { contactId = ContactId 2
    , contactName = "김철수"
    , contactPhone = Just "010-9876-5432"
    , contactEmail = Just "kim@example.com"
    , contactAddress = Nothing
    }

testFilePath :: FilePath
testFilePath = "test_contacts.json"

-- Clean up test file
cleanup :: IO ()
cleanup = do
    exists <- doesFileExist testFilePath
    if exists
        then removeFile testFilePath
        else return ()

main :: IO ()
main = do
    putStrLn "Testing ContactRepository implementation..."
    
    -- Clean up any existing test file
    cleanup
    
    -- Test 1: Load from non-existent file should return empty list
    putStrLn "\nTest 1: Loading from non-existent file"
    result1 <- loadContactsFromFile testFilePath
    case result1 of
        Right [] -> putStrLn "✓ PASS: Empty list returned for non-existent file"
        Right contacts -> putStrLn $ "✗ FAIL: Expected empty list, got: " ++ show contacts
        Left err -> putStrLn $ "✗ FAIL: Unexpected error: " ++ err
    
    -- Test 2: Save contacts to file
    putStrLn "\nTest 2: Saving contacts to file"
    let testContacts = [testContact1, testContact2]
    result2 <- saveContactsToFile testFilePath testContacts
    case result2 of
        Right () -> putStrLn "✓ PASS: Contacts saved successfully"
        Left err -> putStrLn $ "✗ FAIL: Save failed: " ++ err
    
    -- Test 3: Load contacts from file
    putStrLn "\nTest 3: Loading contacts from file"
    result3 <- loadContactsFromFile testFilePath
    case result3 of
        Right loadedContacts -> do
            if length loadedContacts == 2
                then putStrLn "✓ PASS: Correct number of contacts loaded"
                else putStrLn $ "✗ FAIL: Expected 2 contacts, got " ++ show (length loadedContacts)
            
            if testContact1 `elem` loadedContacts && testContact2 `elem` loadedContacts
                then putStrLn "✓ PASS: All test contacts found in loaded data"
                else putStrLn "✗ FAIL: Test contacts not found in loaded data"
        Left err -> putStrLn $ "✗ FAIL: Load failed: " ++ err
    
    -- Test 4: Save empty list
    putStrLn "\nTest 4: Saving empty contact list"
    result4 <- saveContactsToFile testFilePath []
    case result4 of
        Right () -> putStrLn "✓ PASS: Empty list saved successfully"
        Left err -> putStrLn $ "✗ FAIL: Save empty list failed: " ++ err
    
    -- Test 5: Load empty list
    putStrLn "\nTest 5: Loading empty contact list"
    result5 <- loadContactsFromFile testFilePath
    case result5 of
        Right [] -> putStrLn "✓ PASS: Empty list loaded successfully"
        Right contacts -> putStrLn $ "✗ FAIL: Expected empty list, got: " ++ show contacts
        Left err -> putStrLn $ "✗ FAIL: Load empty list failed: " ++ err
    
    -- Clean up
    cleanup
    putStrLn "\nAll tests completed!"