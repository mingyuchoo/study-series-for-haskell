module Services.ValidationService
    ( ValidationService(..)
    , ValidationError(..)
    , validateEmail
    , validatePhone
    , validateContactData
    ) where

import Data.Text (Text)
import qualified Data.Text as T
import Models.Contact (Contact(..))
import Text.Regex.TDFA ((=~))

-- | Validation error types
data ValidationError
    = EmptyName
    | InvalidEmail
    | InvalidPhone
    deriving (Show, Eq)

-- | Interface for contact validation
class ValidationService m where
    validateContact :: Contact -> m (Either [ValidationError] Contact)

-- | Validate email format using regex
validateEmail :: Maybe Text -> Bool
validateEmail Nothing = True  -- Optional field, so Nothing is valid
validateEmail (Just email) = 
    let emailPattern :: String
        emailPattern = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
    in T.unpack email =~ emailPattern

-- | Validate phone number format (digits, spaces, hyphens, parentheses only)
validatePhone :: Maybe Text -> Bool
validatePhone Nothing = True  -- Optional field, so Nothing is valid
validatePhone (Just phone) = 
    let phonePattern :: String
        phonePattern = "^[0-9 ()+-]+$"
    in T.unpack phone =~ phonePattern

-- | Validate a complete contact (pure function)
validateContactData :: Contact -> Either [ValidationError] Contact
validateContactData contact = 
    let errors = collectErrors contact
    in if null errors
       then Right contact
       else Left errors
  where
    collectErrors :: Contact -> [ValidationError]
    collectErrors c = 
        let nameErrors = if T.null (T.strip (contactName c)) 
                        then [EmptyName] 
                        else []
            emailErrors = if validateEmail (contactEmail c) 
                         then [] 
                         else [InvalidEmail]
            phoneErrors = if validatePhone (contactPhone c) 
                         then [] 
                         else [InvalidPhone]
        in nameErrors ++ emailErrors ++ phoneErrors