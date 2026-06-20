{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}

module TodoRepoMock
  ( MockM
  , runMockM
  ) where

import Control.Monad.State

import TodoRepo

import TodoTypes

-- | Mock 모나드 (테스트용)
type MockM = State [Todo]

-- | Mock 모나드 실행 함수
runMockM :: [Todo] -> MockM a -> (a, [Todo])
runMockM initialState action = runState action initialState

-- | Mock Repository 인스턴스 (메모리 기반 테스트 구현)
instance MonadTodoRepo MockM where
  -- \| 모든 할일 목록 조회
  getAllTodos = get

  -- \| 할일 추가
  insertTodo todo = do
    todos <- get
    let newTodos = todo : todos
    put newTodos
    return todo

  -- \| 할일 수정
  updateTodo todoId todo = do
    todos <- get
    let updatedTodos = map (\t -> if _todoId t == fromIntegral todoId then todo else t) todos
    put updatedTodos

  -- \| 할일 삭제
  deleteTodo todoId = do
    todos <- get
    let filteredTodos = filter (\t -> _todoId t /= fromIntegral todoId) todos
    put filteredTodos

  -- \| 데이터베이스 초기화 (Mock에서는 아무 작업 안함)
  initializeDb = return ()
