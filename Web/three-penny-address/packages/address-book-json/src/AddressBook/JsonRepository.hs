module AddressBook.JsonRepository (openJsonRepository) where

import AddressBook.Application (ContactError (..), ContactRepository (..))
import AddressBook.Domain.State (AddressBookState, emptyAddressBookState)
import AddressBook.JsonRepository.Format (decodeAddressBook, encodeAddressBook)
import Control.Concurrent.MVar (newMVar, withMVar)
import Control.Exception (IOException, try)
import Data.Bifunctor (first)
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Lazy as LazyByteString
import System.Directory (canonicalizePath, renameFile)
import System.FilePath (takeDirectory)
import System.IO (hClose)
import System.IO.Error (isDoesNotExistError)
import System.IO.Temp (withTempFile)

openJsonRepository :: FilePath -> IO (ContactRepository IO)
openJsonRepository path = do
  lock <- newMVar ()
  let load = readAddressBook path
      modify change = withMVar lock $ \() -> do
        current <- load
        case current >>= change of
          Left err -> pure (Left err)
          Right updated -> fmap (updated <$) (writeAddressBook path updated)
  pure (ContactRepository load modify)

readAddressBook :: FilePath -> IO (Either ContactError AddressBookState)
readAddressBook path = do
  result <- try (ByteString.readFile path)
  pure $ case result of
    Left exception
      | isDoesNotExistError exception -> Right emptyAddressBookState
      | otherwise -> Left (ioFailure "reading" exception)
    Right contents ->
      first (PersistenceFailure . ("JSON parsing error: " ++)) (decodeAddressBook contents)

writeAddressBook :: FilePath -> AddressBookState -> IO (Either ContactError ())
writeAddressBook path addressBook =
  first (ioFailure "writing") <$> try (do
    destination <- canonicalizePath path
    withTempFile (takeDirectory destination) ".contacts.json" $ \temporaryPath handle -> do
      LazyByteString.hPut handle (encodeAddressBook addressBook)
      hClose handle
      renameFile temporaryPath destination)

ioFailure :: String -> IOException -> ContactError
ioFailure operation exception =
  PersistenceFailure ("IO Error " ++ operation ++ " file: " ++ show exception)
