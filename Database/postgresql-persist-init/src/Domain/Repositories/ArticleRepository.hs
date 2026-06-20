{-# LANGUAGE RankNTypes #-}

module Domain.Repositories.ArticleRepository
    ( ArticleRepository (..)
    ) where

import           Domain.Entities.Article
import           Domain.Entities.User    (User, UserId)

-- Repository interface (port) - defines what we need, not how
class (Monad m) => ArticleRepository m where
  findArticleById :: ArticleId -> m (Maybe Article)
  findArticlesByAuthor :: UserId -> m [Article]
  findRecentArticles :: Int -> m [(User, Article)]
  saveArticle :: Article -> m ArticleId
  deleteArticle :: ArticleId -> m Bool
