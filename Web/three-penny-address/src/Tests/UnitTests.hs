{-# OPTIONS_GHC -fno-hpc #-}

module Tests.UnitTests
    ( unitTests
    ) where

import Test.Hspec
import Data.Aeson (decode, encode)
import qualified Data.Map as Map
import Models.AddressBookState (AddressBookState(..), addressBookFromContacts, emptyAddressBookState)
import Models.Contact (Contact(..), ContactId(..))
import Models.AppState (AppState(..))
import Services.ValidationService (validateEmail, validatePhone, validateContactData, ValidationError(..))
import Services.SearchService (SearchService(..), searchContacts, filterContacts)
import Services.ContactService (addContact, updateContact, deleteContact, generateNextId)
import Services.ContactRepository (ContactRepository(..), FileContactRepository(..), loadContactsFromFile, saveContactsToFile)
import System.Directory (createDirectory, doesFileExist, getPermissions, removeDirectory, removeFile, setOwnerReadable, setPermissions, withCurrentDirectory)

-- | Main unit test suite
unitTests :: Spec
unitTests = do
  describe "ValidationService" $ do
    validationTests
  
  describe "SearchService" $ do
    searchTests
    
  describe "ContactService" $ do
    contactServiceTests
    
  describe "ContactRepository" $ do
    repositoryTests

  describe "Model instances" $ do
    modelInstanceTests

-- | Validation service tests
validationTests :: Spec
validationTests = do
  describe "validateEmail" $ do
    it "accepts valid email addresses" $ do
      validateEmail (Just "test@example.com") `shouldBe` True
      validateEmail (Just "user.name+tag@domain.co.uk") `shouldBe` True
      
    it "rejects invalid email addresses" $ do
      validateEmail (Just "invalid-email") `shouldBe` False
      validateEmail (Just "@domain.com") `shouldBe` False
      validateEmail (Just "user@") `shouldBe` False
      
    it "accepts Nothing (optional field)" $ do
      validateEmail Nothing `shouldBe` True
      
  describe "validatePhone" $ do
    it "accepts valid phone numbers" $ do
      validatePhone (Just "010-1234-5678") `shouldBe` True
      validatePhone (Just "(02) 123-4567") `shouldBe` True
      validatePhone (Just "123 456 7890") `shouldBe` True
      
    it "rejects invalid phone numbers" $ do
      validatePhone (Just "abc-def-ghij") `shouldBe` False
      validatePhone (Just "123-456-789a") `shouldBe` False
      
    it "accepts Nothing (optional field)" $ do
      validatePhone Nothing `shouldBe` True
      
  describe "validateContactData" $ do
    it "accepts valid contact" $ do
      let contact = Contact (ContactId 1) "John Doe" (Just "010-1234-5678") (Just "john@example.com") Nothing
      validateContactData contact `shouldBe` Right contact
      
    it "rejects contact with empty name" $ do
      let contact = Contact (ContactId 1) "" (Just "010-1234-5678") (Just "john@example.com") Nothing
      validateContactData contact `shouldBe` Left [EmptyName]
      
    it "rejects contact with invalid email" $ do
      let contact = Contact (ContactId 1) "John Doe" (Just "010-1234-5678") (Just "invalid-email") Nothing
      validateContactData contact `shouldBe` Left [InvalidEmail]

    it "collects multiple validation errors" $ do
      let contact = Contact (ContactId 1) "   " (Just "bad phone") (Just "invalid-email") Nothing
      validateContactData contact `shouldBe` Left [EmptyName, InvalidEmail, InvalidPhone]

    it "has useful derived instances for validation errors" $ do
      show EmptyName `shouldBe` "EmptyName"
      EmptyName == EmptyName `shouldBe` True
      EmptyName == InvalidEmail `shouldBe` False

-- | Search service tests  
searchTests :: Spec
searchTests = do
  let contacts = [ Contact (ContactId 1) "John Doe" (Just "010-1234-5678") (Just "john@example.com") Nothing
                 , Contact (ContactId 2) "Jane Smith" (Just "010-9876-5432") (Just "jane@example.com") Nothing
                 , Contact (ContactId 3) "Bob Johnson" (Just "010-5555-1234") (Just "bob@test.com") Nothing
                 , Contact (ContactId 4) "No Details" Nothing Nothing (Just "Hidden address")
                 ]
                 
  describe "searchContacts" $ do
    it "returns all contacts for empty search" $ do
      searchContacts "" contacts `shouldBe` contacts
      searchContacts "   " contacts `shouldBe` contacts
      
    it "filters by name (case insensitive)" $ do
      let result = searchContacts "john" contacts
      length result `shouldBe` 2
      map contactName result `shouldContain` ["John Doe", "Bob Johnson"]
      
    it "filters by email" $ do
      let result = searchContacts "test.com" contacts
      map contactName result `shouldBe` ["Bob Johnson"]
      
    it "filters by phone" $ do
      let result = searchContacts "9876" contacts
      map contactName result `shouldBe` ["Jane Smith"]
      
    it "returns empty list for no matches" $ do
      searchContacts "nonexistent" contacts `shouldBe` []

    it "handles missing optional fields while searching" $ do
      searchContacts "missing" contacts `shouldBe` []

    it "supports the compatibility alias" $ do
      filterContacts "jane" contacts `shouldBe` searchContacts "jane" contacts

    it "supports the IO service interface" $ do
      result <- searchContactsM "bob" contacts
      map contactName result `shouldBe` ["Bob Johnson"]

-- | Contact service tests
contactServiceTests :: Spec
contactServiceTests = do
  let emptyState = emptyAddressBookState
      sampleContact = Contact (ContactId 0) "Test User" (Just "010-1234-5678") (Just "test@example.com") Nothing
      
  describe "addContact" $ do
    it "adds valid contact to empty state" $ do
      case addContact sampleContact emptyState of
        Right newState -> do
          Map.size (addressContacts newState) `shouldBe` 1
          addressNextId newState `shouldBe` ContactId 2
        Left _ -> expectationFailure "Should have succeeded"
        
    it "rejects invalid contact" $ do
      let invalidContact = Contact (ContactId 0) "" Nothing Nothing Nothing
      case addContact invalidContact emptyState of
        Left errors -> errors `shouldContain` [EmptyName]
        Right _ -> expectationFailure "Should have failed"

    it "stores the generated contact id in the inserted contact" $ do
      let state = emptyState { addressNextId = ContactId 10 }
      case addContact sampleContact state of
        Right newState -> do
          Map.keys (addressContacts newState) `shouldBe` [ContactId 10]
          fmap contactId (Map.lookup (ContactId 10) (addressContacts newState)) `shouldBe` Just (ContactId 10)
          addressNextId newState `shouldBe` ContactId 11
        Left errors -> expectationFailure $ "Should have succeeded: " ++ show errors
        
  describe "updateContact" $ do
    it "updates existing contact" $ do
      -- First add a contact
      case addContact sampleContact emptyState of
        Right stateWithContact -> do
          let updatedContact = Contact (ContactId 1) "Updated Name" (Just "010-9999-9999") (Just "updated@example.com") Nothing
          case updateContact updatedContact stateWithContact of
            Right finalState -> do
              Map.size (addressContacts finalState) `shouldBe` 1
              let maybeContact = Map.lookup (ContactId 1) (addressContacts finalState)
              case maybeContact of
                Just contact -> contactName contact `shouldBe` "Updated Name"
                Nothing -> expectationFailure "Contact should exist"
            Left _ -> expectationFailure "Update should have succeeded"
        Left _ -> expectationFailure "Initial add should have succeeded"

    it "inserts a valid contact when the id does not already exist" $ do
      let updatedContact = Contact (ContactId 42) "Inserted Name" Nothing Nothing Nothing
      case updateContact updatedContact emptyState of
        Right finalState ->
          Map.lookup (ContactId 42) (addressContacts finalState) `shouldBe` Just updatedContact
        Left errors -> expectationFailure $ "Update should have succeeded: " ++ show errors

    it "rejects invalid updated contact" $ do
      let invalidContact = Contact (ContactId 42) "" Nothing Nothing Nothing
      updateContact invalidContact emptyState `shouldBe` Left [EmptyName]
        
  describe "deleteContact" $ do
    it "removes existing contact" $ do
      -- First add a contact
      case addContact sampleContact emptyState of
        Right stateWithContact -> do
          let finalState = deleteContact (ContactId 1) stateWithContact
          Map.size (addressContacts finalState) `shouldBe` 0
        Left _ -> expectationFailure "Initial add should have succeeded"

    it "leaves state unchanged when deleting a missing contact" $ do
      deleteContact (ContactId 99) emptyState `shouldBe` emptyState
        
  describe "generateNextId" $ do
    it "increments ContactId correctly" $ do
      generateNextId (ContactId 1) `shouldBe` ContactId 2
      generateNextId (ContactId 99) `shouldBe` ContactId 100

-- | Repository tests
repositoryTests :: Spec
repositoryTests = do
  let testFile = "test_contacts.json"
      testContacts = [ Contact (ContactId 1) "Test User 1" (Just "010-1111-1111") (Just "test1@example.com") Nothing
                     , Contact (ContactId 2) "Test User 2" (Just "010-2222-2222") (Just "test2@example.com") Nothing
                     ]
  
  describe "file operations" $ do
    it "saves and loads contacts correctly" $ do
      -- Clean up any existing test file
      fileExists <- doesFileExist testFile
      if fileExists then removeFile testFile else return ()
      
      -- Save contacts
      saveResult <- saveContactsToFile testFile testContacts
      saveResult `shouldBe` Right ()
      
      -- Load contacts back
      loadResult <- loadContactsFromFile testFile
      case loadResult of
        Right loadedContacts -> do
          length loadedContacts `shouldBe` 2
          map contactName loadedContacts `shouldBe` ["Test User 1", "Test User 2"]
        Left err -> expectationFailure $ "Load failed: " ++ err
      
      -- Clean up
      removeFile testFile

    it "saves and loads an empty contact list" $ do
      let emptyFile = "empty_contacts.json"
      fileExists <- doesFileExist emptyFile
      if fileExists then removeFile emptyFile else return ()

      saveResult <- saveContactsToFile emptyFile []
      saveResult `shouldBe` Right ()

      loadResult <- loadContactsFromFile emptyFile
      loadResult `shouldBe` Right []

      removeFile emptyFile
      
    it "handles missing file gracefully" $ do
      let nonExistentFile = "nonexistent_file.json"
      result <- loadContactsFromFile nonExistentFile
      result `shouldBe` Right []
      
    it "handles corrupted file gracefully" $ do
      let corruptedFile = "corrupted_test.json"
      -- Create a corrupted JSON file
      writeFile corruptedFile "{ invalid json content"
      
      result <- loadContactsFromFile corruptedFile
      case result of
        Left err -> do
          err `shouldContain` "JSON parsing error:"
          length err `shouldSatisfy` (> length ("JSON parsing error:" :: String))
        Right _ -> expectationFailure "Should have failed on corrupted file"
      
      -- Clean up
      removeFile corruptedFile

    it "reports read IO errors" $ do
      let unreadableFile = "contact_repository_unreadable.json"
      writeFile unreadableFile "{}"
      permissions <- getPermissions unreadableFile
      setPermissions unreadableFile (setOwnerReadable False permissions)

      result <- loadContactsFromFile unreadableFile
      case result of
        Left err -> do
          err `shouldContain` "IO Error reading file:"
          length err `shouldSatisfy` (> length ("IO Error reading file:" :: String))
        Right _ -> expectationFailure "Should have failed on unreadable file"

      setPermissions unreadableFile permissions
      removeFile unreadableFile

    it "reports write IO errors" $ do
      let directoryPath = "contact_repository_write_dir"
      createDirectory directoryPath

      result <- saveContactsToFile directoryPath testContacts
      case result of
        Left err -> do
          err `shouldContain` "IO Error writing file:"
          length err `shouldSatisfy` (> length ("IO Error writing file:" :: String))
        Right _ -> expectationFailure "Should have failed on directory output"

      removeDirectory directoryPath

    it "exposes repository path and derived instances" $ do
      let repository = FileContactRepository "contacts.json"
      repositoryFilePath repository `shouldBe` "contacts.json"
      show repository `shouldBe` "FileContactRepository {repositoryFilePath = \"contacts.json\"}"
      repository == FileContactRepository "contacts.json" `shouldBe` True
      repository == FileContactRepository "other.json" `shouldBe` False

    it "supports the IO repository interface defaults" $ do
      let repositoryDir = "contact_repository_interface_dir"
      createDirectory repositoryDir

      withCurrentDirectory repositoryDir $ do
        saveResult <- saveContacts testContacts
        saveResult `shouldBe` Right ()

        loadResult <- loadContacts
        case loadResult of
          Right loadedContacts -> map contactName loadedContacts `shouldBe` ["Test User 1", "Test User 2"]
          Left err -> expectationFailure $ "Load failed: " ++ err

        removeFile "contacts.json"

      removeDirectory repositoryDir

-- | Model instance tests
modelInstanceTests :: Spec
modelInstanceTests = do
  let contact = Contact (ContactId 1) "Instance User" (Just "010-1111-2222") (Just "instance@example.com") (Just "Seoul")
      addressBook = AddressBookState (Map.singleton (ContactId 1) contact) (ContactId 2)
      appState = AppState addressBook "instance"

  it "covers ContactId derived instances" $ do
    show (ContactId 1) `shouldBe` "ContactId 1"
    ContactId 1 == ContactId 1 `shouldBe` True
    ContactId 1 == ContactId 2 `shouldBe` False
    compare (ContactId 1) (ContactId 2) `shouldBe` LT

  it "covers Contact derived instances and address accessor" $ do
    show contact `shouldContain` "Instance User"
    contact == contact `shouldBe` True
    contact == contact { contactAddress = Nothing } `shouldBe` False
    contactAddress contact `shouldBe` Just "Seoul"

  it "round-trips Contact JSON" $ do
    decode (encode contact) `shouldBe` Just contact

  it "round-trips AddressBookState JSON" $ do
    decode (encode addressBook) `shouldBe` Just addressBook

  it "builds AddressBookState from contacts" $ do
    addressBookFromContacts [contact] `shouldBe` addressBook

  it "round-trips AppState JSON" $ do
    decode (encode appState) `shouldBe` Just appState

  it "covers AppState derived instances and accessors" $ do
    show appState `shouldContain` "Instance User"
    appState == appState `shouldBe` True
    appState == appState { searchTerm = "other" } `shouldBe` False
    appAddressBook appState `shouldBe` addressBook
    searchTerm appState `shouldBe` "instance"
    decode (encode appState) `shouldBe` Just appState
