{-# LANGUAGE OverloadedStrings #-}

-- 도메인 계층: 순수 비즈니스 엔티티와 규칙만 포함
module Domain.UserModel
  ( User (..)
  ) where

import Data.Aeson
  ( FromJSON (..)
  , ToJSON (..)
  , object
  , withObject
  , (.!=)
  , (.:)
  , (.:?)
  , (.=)
  )
import Data.Text qualified as T

-- 사용자 엔티티 (DB, 웹 프레임워크 등 인프라에 독립적)
data User = User
  { userId   :: Maybe Int
  , userName :: T.Text
  }
  deriving (Show)

instance ToJSON User where
  toJSON (User i n) = object ["id" .= i, "name" .= n]

instance FromJSON User where
  parseJSON = withObject "User" $ \v ->
    User
      <$> v .:? "id" .!= Nothing
      <*> v .: "name"
