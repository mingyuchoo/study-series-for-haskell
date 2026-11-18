module AddressBook.Http (addressBookApplication) where

import AddressBook.Application
  ( ContactError (..), ContactRepository (..), listContacts, removeContact, saveContact )
import AddressBook.Domain.Contact (Contact (..), ContactId (..))
import AddressBook.Domain.Validation (ValidationError (..))
import Control.Monad (join)
import Data.Aeson (FromJSON (parseJSON), ToJSON, Value, eitherDecode, encode, object, withObject, (.:), (.:?), (.=))
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding (decodeUtf8')
import Network.HTTP.Types
import Network.Wai
import System.FilePath ((</>))
import Text.Read (readMaybe)

data ContactInput = ContactInput (Maybe ContactId) Text Text Text Text

instance FromJSON ContactInput where
  parseJSON = withObject "Contact input" $ \fields -> do
    rawIdentifier <- fields .:? "id"
    identifier <- traverse (maybe (fail "Invalid contact identifier.") pure . parseContactId) rawIdentifier
    ContactInput identifier <$> fields .: "name" <*> fields .: "phone"
      <*> fields .: "email" <*> fields .: "address"

addressBookApplication :: FilePath -> ContactRepository IO -> Application
addressBookApplication staticDirectory repository request respond =
  case (requestMethod request, pathInfo request) of
    ("GET", []) -> serve "index.html" "text/html; charset=utf-8"
    ("GET", ["elm.js"]) -> serve "elm.js" "text/javascript; charset=utf-8"
    ("GET", ["api", "contacts"]) ->
      case traverse decodeUtf8' (join $ lookup "q" $ queryString request) of
        Left _ -> respond $ errorResponse status400 "Invalid search query."
        Right query -> do
          result <- loadAddressBook repository
          respond $ case result of
            Left err -> contactErrorResponse err
            Right book -> jsonResponse status200 $ map contactValue $ listContacts (maybe "" id query) book
    ("POST", ["api", "contacts"])
      | lookup hContentType (requestHeaders request) == Just "application/json" -> do
          body <- lazyRequestBody request
          case eitherDecode body of
            Left _ -> respond $ errorResponse status400 "Invalid contact data."
            Right (ContactInput identifier name phone email address) ->
              saveContact repository identifier name
                (nonBlank phone) (nonBlank email) (nonBlank address) >>= respond . mutationResponse
      | otherwise -> respond $ errorResponse status415 "Expected application/json."
    ("DELETE", ["api", "contacts", identifier]) ->
      case parseContactId identifier of
        Nothing -> respond $ errorResponse status400 "Invalid contact identifier."
        Just key -> removeContact repository key >>= respond . mutationResponse
    _ -> respond $ errorResponse status404 "Not found."
  where
    serve filename mediaType =
      respond $ responseFile status200 [(hContentType, mediaType), (hCacheControl, "no-cache")]
        (staticDirectory </> filename) Nothing

nonBlank :: Text -> Maybe Text
nonBlank input
  | Text.null (Text.strip input) = Nothing
  | otherwise = Just input

parseContactId :: Text -> Maybe ContactId
parseContactId rawIdentifier = do
  identifier <- readMaybe (Text.unpack rawIdentifier)
  if Text.pack (show (identifier :: Int)) == rawIdentifier
    then Just (ContactId identifier)
    else Nothing

contactValue :: Contact -> Value
contactValue (Contact (ContactId identifier) name phone email address) =
  object ["id" .= show identifier, "name" .= name, "phone" .= phone, "email" .= email, "address" .= address]

mutationResponse :: Either ContactError a -> Response
mutationResponse = either contactErrorResponse (const $ responseLBS status204 [] "")

contactErrorResponse :: ContactError -> Response
contactErrorResponse err = case err of
  ValidationFailure errors -> errorResponse status422 $ Text.unlines $ map validationMessage errors
  ContactNotFound _ -> errorResponse status404 "This contact was deleted in another window."
  PersistenceFailure message -> errorResponse status500 (Text.pack message)

validationMessage :: ValidationError -> Text
validationMessage EmptyName = "Name is required and cannot be empty."
validationMessage InvalidEmail = "Invalid email format."
validationMessage InvalidPhone = "Invalid phone number format. Use only digits, spaces, hyphens, and parentheses."

errorResponse :: Status -> Text -> Response
errorResponse status message = jsonResponse status $ object ["message" .= message]

jsonResponse :: ToJSON a => Status -> a -> Response
jsonResponse status = responseLBS status [(hContentType, "application/json"), (hCacheControl, "no-store")] . encode
