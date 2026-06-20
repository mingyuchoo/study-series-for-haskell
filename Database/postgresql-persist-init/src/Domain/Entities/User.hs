{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE OverloadedStrings #-}

module Domain.Entities.User
    ( User (..)
    , UserAge (..)
    , UserEmail (..)
    , UserId (..)
    , UserName (..)
    , UserOccupation (..)
    , mkUser
    , validateUser
    ) where

import           Data.Int     (Int64)
import           Data.Text    (Text)
import qualified Data.Text    as T

import           GHC.Generics (Generic)

-- Domain types with validation
newtype UserId = UserId Int64
     deriving (Eq, Generic, Read, Show)
newtype UserEmail = UserEmail Text
     deriving (Eq, Generic, Read, Show)
newtype UserName = UserName Text
     deriving (Eq, Generic, Read, Show)
newtype UserAge = UserAge Int
     deriving (Eq, Generic, Read, Show)
newtype UserOccupation = UserOccupation Text
     deriving (Eq, Generic, Read, Show)

-- Core domain entity
data User = User { userId         :: Maybe UserId
                 , userName       :: UserName
                 , userEmail      :: UserEmail
                 , userAge        :: UserAge
                 , userOccupation :: UserOccupation
                 }
     deriving (Eq, Generic, Read, Show)

-- Smart constructor with validation
mkUser :: Text -> Text -> Int -> Text -> Either Text User
mkUser name email age occupation
  | T.null name = Left "Name cannot be empty"
  | T.null email = Left "Email cannot be empty"
  | age < 0 = Left "Age cannot be negative"
  | age > 150 = Left "Age cannot exceed 150"
  | T.null occupation = Left "Occupation cannot be empty"
  | otherwise =
      Right $
        User
          { userId = Nothing
          , userName = UserName name
          , userEmail = UserEmail email
          , userAge = UserAge age
          , userOccupation = UserOccupation occupation
          }

-- Domain validation
validateUser :: User -> Either Text User
validateUser user@(User _ (UserName name) (UserEmail email) (UserAge age) (UserOccupation occupation))
  | T.null name = Left "Name cannot be empty"
  | T.null email = Left "Email cannot be empty"
  | age < 0 = Left "Age cannot be negative"
  | age > 150 = Left "Age cannot exceed 150"
  | T.null occupation = Left "Occupation cannot be empty"
  | otherwise = Right user
