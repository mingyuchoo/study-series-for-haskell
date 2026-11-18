module AddressBook.Domain.Validation
    ( ValidationError (..)
    , validateContactData
    , validateEmail
    , validatePhone
    ) where

import           Data.Text       (Text)
import qualified Data.Text       as T

import           AddressBook.Domain.Contact  (Contact (..))

import           Data.Char (isAsciiLower, isAsciiUpper, isDigit)

data ValidationError = EmptyName | InvalidEmail | InvalidPhone
     deriving (Eq, Show)

validateEmail :: Maybe Text -> Bool
validateEmail = maybe True (any validEmail . T.splitOn "\n")

validEmail :: Text -> Bool
validEmail email =
  case T.splitOn "@" email of
    [local, domain] ->
      not (T.null local)
        && T.all (\character -> isAsciiLetter character || isDigit character || character `elem` ("._%+-" :: String)) local
        && validDomain domain
    _ -> False

validDomain :: Text -> Bool
validDomain domain =
  let (prefixWithDot, suffix) = T.breakOnEnd "." domain
      prefix = T.dropEnd 1 prefixWithDot
   in not (T.null prefix)
        && T.all (\character -> isAsciiLetter character || isDigit character || character `elem` (".-" :: String)) prefix
        && T.length suffix >= 2
        && T.all isAsciiLetter suffix

isAsciiLetter :: Char -> Bool
isAsciiLetter character = isAsciiLower character || isAsciiUpper character

validatePhone :: Maybe Text -> Bool
validatePhone = maybe True (any validPhone . T.splitOn "\n")

validPhone :: Text -> Bool
validPhone phone =
  not (T.null phone)
    && T.all (\character -> isDigit character || character `elem` (" ()+-" :: String)) phone

validateContactData :: Contact -> Either [ValidationError] Contact
validateContactData contact =
  let errors = collectErrors contact
   in if null errors
        then Right contact
        else Left errors
  where
    collectErrors :: Contact -> [ValidationError]
    collectErrors c =
      let nameErrors =
            if T.null (T.strip (contactName c))
              then [EmptyName]
              else []
          emailErrors =
            if validateEmail (contactEmail c)
              then []
              else [InvalidEmail]
          phoneErrors =
            if validatePhone (contactPhone c)
              then []
              else [InvalidPhone]
       in nameErrors ++ emailErrors ++ phoneErrors
