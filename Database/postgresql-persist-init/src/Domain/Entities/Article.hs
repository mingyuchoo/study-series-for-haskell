{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE OverloadedStrings #-}

module Domain.Entities.Article
    ( Article (..)
    , ArticleBody (..)
    , ArticleId
    , ArticleTitle (..)
    , mkArticle
    , validateArticle
    ) where

import           Data.Int             (Int64)
import           Data.Text            (Text)
import qualified Data.Text            as T
import           Data.Time            (UTCTime)

import           Domain.Entities.User (UserId)

import           GHC.Generics         (Generic)

-- Domain types
newtype ArticleId = ArticleId Int64
     deriving (Eq, Generic, Show)
newtype ArticleTitle = ArticleTitle Text
     deriving (Eq, Generic, Show)
newtype ArticleBody = ArticleBody Text
     deriving (Eq, Generic, Show)

-- Core domain entity
data Article = Article { articleId            :: Maybe ArticleId
                       , articleTitle         :: ArticleTitle
                       , articleBody          :: ArticleBody
                       , articlePublishedTime :: UTCTime
                       , articleAuthorId      :: UserId
                       }
     deriving (Eq, Generic, Show)

-- Smart constructor with validation
mkArticle :: Text -> Text -> UTCTime -> UserId -> Either Text Article
mkArticle title body publishedTime authorId
  | T.null title = Left "Title cannot be empty"
  | T.null body = Left "Body cannot be empty"
  | otherwise =
      Right $
        Article
          { articleId = Nothing
          , articleTitle = ArticleTitle title
          , articleBody = ArticleBody body
          , articlePublishedTime = publishedTime
          , articleAuthorId = authorId
          }

-- Domain validation
validateArticle :: Article -> Either Text Article
validateArticle article@(Article _ (ArticleTitle title) (ArticleBody body) _ _)
  | T.null title = Left "Title cannot be empty"
  | T.null body = Left "Body cannot be empty"
  | otherwise = Right article
