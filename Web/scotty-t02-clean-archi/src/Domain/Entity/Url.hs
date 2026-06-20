{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE OverloadedStrings #-}

module Domain.Entity.Url
  ( TempUrl (..)
  , Url (..)
  , UrlId
  , generateShortUrl
  , mkUrl
  , mkUrlWithMetadata
  ) where

import Data.Aeson (FromJSON, ToJSON)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Time (UTCTime)

import GHC.Generics (Generic)

type UrlId = Int

data Url = Url
  { urlId       :: UrlId
  , originalUrl :: Text
  , shortUrl    :: Text
  , createdAt   :: UTCTime
  }
  deriving (Eq, Generic, Show)

instance ToJSON Url
instance FromJSON Url

-- Temporary URL for validation, will be populated with proper metadata in repository
newtype TempUrl = TempUrl { getTempUrl :: Text }
  deriving (Eq, Show)

mkUrl :: Text -> Maybe TempUrl
mkUrl text
  | text == "" = Nothing
  | T.length text > 2048 = Nothing -- URL too long
  | not (isValidUrl text) = Nothing
  | otherwise = Just $ TempUrl text

mkUrlWithMetadata :: UrlId -> Text -> Text -> UTCTime -> Url
mkUrlWithMetadata uid original short created = Url uid original short created

generateShortUrl :: UrlId -> Text
generateShortUrl uid = T.pack $ "http://localhost:8000/" ++ show uid

isValidUrl :: Text -> Bool
isValidUrl url =
  T.isPrefixOf "http://" url || T.isPrefixOf "https://" url
