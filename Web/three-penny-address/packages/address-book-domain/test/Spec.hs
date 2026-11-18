import qualified Data.Map as Map
import AddressBook.Domain.State
import AddressBook.Domain.Contact
import AddressBook.Domain.Contacts
import AddressBook.Domain.Search
import AddressBook.Domain.Validation
import Test.Hspec

main :: IO ()
main = hspec $ do
  validationTests
  searchTests
  contactServiceTests

  describe "legacy validation" $ do
    it "matches valid email and phone lines within multiline values" $ do
      validateEmail (Just "invalid\nkim@example.com\ninvalid") `shouldBe` True
      validatePhone (Just "invalid\n010-1234-5678\ninvalid") `shouldBe` True

  describe "address book state" $ do
    it "keeps stable ID order and computes the next ID" $ do
      let firstContact = Contact (ContactId 2) "Kim" Nothing Nothing Nothing
          secondContact = Contact (ContactId 7) "Lee" Nothing Nothing Nothing
          addressBook = addressBookFromContacts [secondContact, firstContact]
      addressBookToContacts addressBook `shouldBe` [firstContact, secondContact]
      addressNextId addressBook `shouldBe` ContactId 8

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
      let contact =
            Contact (ContactId 1) "John Doe" (Just "010-1234-5678") (Just "john@example.com") Nothing
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

searchTests :: Spec
searchTests = do
  let contacts =
        [ Contact (ContactId 1) "John Doe" (Just "010-1234-5678") (Just "john@example.com") Nothing
        , Contact
            (ContactId 2)
            "Jane Smith"
            (Just "010-9876-5432")
            (Just "jane@example.com")
            Nothing
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

contactServiceTests :: Spec
contactServiceTests = do
  let emptyState = emptyAddressBookState
      sampleContact =
        Contact (ContactId 0) "Test User" (Just "010-1234-5678") (Just "test@example.com") Nothing

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
        Right _     -> expectationFailure "Should have failed"

    it "stores the generated contact id in the inserted contact" $ do
      let state = emptyState {addressNextId = ContactId 10}
      case addContact sampleContact state of
        Right newState -> do
          Map.keys (addressContacts newState) `shouldBe` [ContactId 10]
          fmap contactId (Map.lookup (ContactId 10) (addressContacts newState))
            `shouldBe` Just (ContactId 10)
          addressNextId newState `shouldBe` ContactId 11
        Left errors -> expectationFailure $ "Should have succeeded: " ++ show errors

  describe "updateContact" $ do
    it "updates existing contact" $ do
      case addContact sampleContact emptyState of
        Right stateWithContact -> do
          let updatedContact =
                Contact
                  (ContactId 1)
                  "Updated Name"
                  (Just "010-9999-9999")
                  (Just "updated@example.com")
                  Nothing
          case updateContact updatedContact stateWithContact of
            Right finalState -> do
              Map.size (addressContacts finalState) `shouldBe` 1
              let maybeContact = Map.lookup (ContactId 1) (addressContacts finalState)
              case maybeContact of
                Just contact -> contactName contact `shouldBe` "Updated Name"
                Nothing      -> expectationFailure "Contact should exist"
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

