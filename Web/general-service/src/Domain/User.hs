{-# LANGUAGE OverloadedStrings #-}

module Domain.User
  ( User (..)
  , UserProfile (..)
  , SignUpInput (..)
  , ProfileUpdate (..)
  , AuthError (..)
  , userProfile
  , validateSignUpInput
  , validateProfileUpdate
  )
where

import Data.Text (Text)
import qualified Data.Text as Text

data User = User
  { userId :: Int
  , userEmail :: Text
  , userDisplayName :: Text
  , userPasswordHash :: Text
  }
  deriving (Eq, Show)

data UserProfile = UserProfile
  { profileId :: Int
  , profileEmail :: Text
  , profileDisplayName :: Text
  }
  deriving (Eq, Show)

data SignUpInput = SignUpInput
  { signUpEmail :: Text
  , signUpDisplayName :: Text
  , signUpPassword :: Text
  }
  deriving (Eq, Show)

newtype ProfileUpdate = ProfileUpdate
  { updatedDisplayName :: Text
  }
  deriving (Eq, Show)

data AuthError
  = InvalidEmail
  | EmptyDisplayName
  | PasswordTooShort
  | DuplicateEmail
  | InvalidCredentials
  | AuthenticationRequired
  deriving (Eq, Show)

userProfile :: User -> UserProfile
userProfile user = UserProfile (userId user) (userEmail user) (userDisplayName user)

validateSignUpInput :: SignUpInput -> Either AuthError SignUpInput
validateSignUpInput input
  | not (isEmail (signUpEmail input)) = Left InvalidEmail
  | Text.null (Text.strip (signUpDisplayName input)) = Left EmptyDisplayName
  | Text.length (signUpPassword input) < 8 = Left PasswordTooShort
  | otherwise = Right input

validateProfileUpdate :: ProfileUpdate -> Either AuthError ProfileUpdate
validateProfileUpdate update
  | Text.null (Text.strip (updatedDisplayName update)) = Left EmptyDisplayName
  | otherwise = Right update

isEmail :: Text -> Bool
isEmail email =
  let trimmed = Text.strip email
      parts = Text.splitOn "@" trimmed
   in length parts == 2
        && not (any Text.null parts)
        && maybe False (Text.isInfixOf ".") (safeLast parts)

safeLast :: [a] -> Maybe a
safeLast [] = Nothing
safeLast values = Just (last values)
