{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}

module TodoRepo
  ( MonadTodoRepo (..)
  , TodoRepoError (..)
  ) where

import Control.Monad.Except

import Data.Text (Text)

import TodoTypes

-- | Repository 에러 타입
data TodoRepoError = TodoNotFound Int
                   | DatabaseError Text
                   | ValidationError Text
  deriving (Eq, Show)

-- | Todo Repository MTL 타입클래스 (데이터 접근 추상화)
class (Monad m) => MonadTodoRepo m where
  -- | 모든 할일 목록 조회
  getAllTodos :: m [Todo]

  -- | 할일 추가
  insertTodo :: Todo -> m Todo

  -- | 할일 수정
  updateTodo :: Int -> Todo -> m ()

  -- | 할일 삭제
  deleteTodo :: Int -> m ()

  -- | 데이터베이스 초기화
  initializeDb :: m ()
