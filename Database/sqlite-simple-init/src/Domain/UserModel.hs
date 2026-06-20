{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric  #-}

module Domain.UserModel
  ( User (..)
  ) where

import Data.Aeson (FromJSON, ToJSON)
import Data.Time

import Database.SQLite.Simple

import GHC.Generics

-- Core domain entity
data User = User
  { userId       :: Maybe Int
  , userName     :: String
  , userEmail    :: String
  , userPassword :: String
  , createdAt    :: UTCTime
  , updatedAt    :: UTCTime
  }
  deriving (FromJSON, Generic, Show, ToJSON)

-- | Database row mapping
instance FromRow User where
  fromRow = User <$> field <*> field <*> field <*> field <*> field <*> field

-- | Database row mapping
instance ToRow User where
  toRow (User uid name email password created updated) =
    toRow (uid, name, email, password, created, updated)
