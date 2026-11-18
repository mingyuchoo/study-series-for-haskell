import AddressBook.Application
import AddressBook.Domain.Contact
import AddressBook.Domain.State
import AddressBook.JsonRepository
import Control.Concurrent.Async (concurrently)
import Data.Text (Text)
import System.Directory (createFileLink, doesFileExist, pathIsSymbolicLink)
import System.FilePath ((</>))
import System.Info (os)
import System.IO.Temp (withSystemTempDirectory)
import Test.Hspec

main :: IO ()
main = hspec $ around (withSystemTempDirectory "address-book-test") $ do
  it "reads legacy contacts and preserves the next ID across writes" $ \directory -> do
    let path = directory </> "contacts.json"
    writeFile path "{\"contacts\":[[7,{\"contactId\":7,\"contactName\":\"Kim\",\"contactPhone\":null,\"contactEmail\":null,\"contactAddress\":null}]],\"nextId\":12}"
    repository <- openJsonRepository path
    let contact = Contact (ContactId 7) "Kim" Nothing Nothing Nothing
    loadAddressBook repository `shouldReturn` Right ((addressBookFromContacts [contact]) {addressNextId = ContactId 12})
    removeContact repository (ContactId 7) `shouldReturn` Right (emptyAddressBookState {addressNextId = ContactId 12})
    reopened <- openJsonRepository path
    loadAddressBook reopened `shouldReturn` Right (emptyAddressBookState {addressNextId = ContactId 12})

  it "returns an empty address book for a missing file" $ \directory -> do
    repository <- openJsonRepository (directory </> "missing.json")
    loadAddressBook repository `shouldReturn` Right emptyAddressBookState

  it "updates the target of a symlinked contacts file" $ \directory -> do
    if os == "mingw32"
      then pendingWith "Creating symlinks on Windows requires additional privileges"
      else do
        let target = directory </> "actual.json"
            link = directory </> "contacts.json"
        writeFile target "{\"contacts\":[],\"nextId\":1}"
        createFileLink target link
        repository <- openJsonRepository link
        let contact = Contact (ContactId 1) "Kim" Nothing Nothing Nothing
        saveContact repository Nothing "Kim" Nothing Nothing Nothing
          `shouldReturn` Right (addressBookFromContacts [contact])
        pathIsSymbolicLink link `shouldReturn` True
        targetRepository <- openJsonRepository target
        loadAddressBook targetRepository `shouldReturn` Right (addressBookFromContacts [contact])

  it "preserves malformed data when a mutation is attempted" $ \directory -> do
    let path = directory </> "contacts.json"
    writeFile path "invalid JSON"
    repository <- openJsonRepository path
    removeContact repository (ContactId 7) >>= (`shouldSatisfy` isPersistenceFailure)
    readFile path `shouldReturn` "invalid JSON"

  it "rejects invalid contacts without creating a file" $ \directory -> do
    let path = directory </> "contacts.json"
    repository <- openJsonRepository path
    saveContact repository Nothing "" Nothing Nothing Nothing >>= (`shouldSatisfy` isValidationFailure)
    doesFileExist path `shouldReturn` False

  it "reports a write failure when the parent directory is missing" $ \directory -> do
    repository <- openJsonRepository (directory </> "missing" </> "contacts.json")
    result <- saveContact repository Nothing "Kim" Nothing Nothing Nothing
    case result of
      Left (PersistenceFailure message) -> message `shouldContain` "IO Error writing file:"
      _ -> expectationFailure (show result)
    loadAddressBook repository `shouldReturn` Right emptyAddressBookState

  it "keeps a deleted contact deleted when an earlier window tries to edit it" $ \directory -> do
    repository <- openJsonRepository (directory </> "contacts.json")
    let identifier = ContactId 1
    _ <- saveContact repository Nothing "Kim" Nothing Nothing Nothing
    removeContact repository identifier `shouldReturn` Right (emptyAddressBookState {addressNextId = ContactId 2})
    saveContact repository (Just identifier) "Edited" Nothing Nothing Nothing
      `shouldReturn` Left (ContactNotFound identifier)
    loadAddressBook repository `shouldReturn` Right (emptyAddressBookState {addressNextId = ContactId 2})

  it "preserves both concurrent additions through the same repository" $ \directory -> do
    repository <- openJsonRepository (directory </> "contacts.json")
    let add name = saveContact repository Nothing name Nothing Nothing Nothing
    _ <- concurrently (add "Kim") (add "Lee")
    book <- loadAddressBook repository
    fmap (map contactName . addressBookToContacts) book `shouldSatisfy` isComplete
    fmap addressNextId book `shouldBe` Right (ContactId 3)

isComplete :: Either ContactError [Text] -> Bool
isComplete result = result == Right ["Kim", "Lee"] || result == Right ["Lee", "Kim"]

isPersistenceFailure :: Either ContactError AddressBookState -> Bool
isPersistenceFailure (Left (PersistenceFailure _)) = True
isPersistenceFailure _ = False

isValidationFailure :: Either ContactError AddressBookState -> Bool
isValidationFailure (Left (ValidationFailure _)) = True
isValidationFailure _ = False
