{-# LANGUAGE FlexibleContexts #-}

module TodoLogic
  ( loadAllTodos
  , removeExistingTodo
  , saveTodo
  , updateExistingTodo
  , validateTodo
  ) where

import Control.Lens
import Control.Monad.IO.Class

import Data.Text (Text)
import Data.Text qualified as T

import TodoRepo

import TodoTypes

-- | 모든 할일 로드
loadAllTodos :: (MonadTodoRepo m, MonadIO m) => m [Todo]
loadAllTodos = getAllTodos

-- | 새 할일 저장
saveTodo :: (MonadTodoRepo m, MonadIO m) => Todo -> m Todo
saveTodo todo = case validateTodo todo of
  Left err    -> error $ T.unpack err -- 실제로는 Either나 ExceptT 사용 권장
  Right valid -> insertTodo valid

-- | 기존 할일 수정
updateExistingTodo :: (MonadTodoRepo m, MonadIO m) => Int -> Todo -> m ()
updateExistingTodo idx todo = case validateTodo todo of
  Left err    -> error $ T.unpack err
  Right valid -> updateTodo idx valid

-- | 할일 삭제
removeExistingTodo :: (MonadTodoRepo m, MonadIO m) => Int -> m ()
removeExistingTodo = deleteTodo

-- | 할일 검증
validateTodo :: Todo -> Either Text Todo
validateTodo todo
  | T.null (todo ^. description) = Left "Description cannot be empty"
  | T.length (todo ^. description) > 200 = Left "Description too long (max 200 characters)"
  | otherwise = Right todo
