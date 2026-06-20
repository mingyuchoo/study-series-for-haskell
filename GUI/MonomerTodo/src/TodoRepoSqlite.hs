{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings     #-}

module TodoRepoSqlite
  ( AppM
  , SqliteEnv (..)
  , runAppM
  , withSqliteEnv
  ) where

import Control.Monad.Except
import Control.Monad.Reader

import Data.Int (Int64)
import Data.Text (Text)
import Data.Text qualified as T

import Database.SQLite.Simple
import Database.SQLite.Simple.FromRow
import Database.SQLite.Simple.ToRow

import TodoRepo

import TodoTypes

-- | SQLite 환경 설정 (데이터베이스 연결 정보)
data SqliteEnv = SqliteEnv
  { sqliteConn :: Connection
  }

-- | 애플리케이션 모나드 (Reader + IO)
type AppM = ReaderT SqliteEnv IO

-- | AppM 모나드 실행 함수
runAppM :: SqliteEnv -> AppM a -> IO a
runAppM env action = runReaderT action env

-- | SQLite 환경 생성 및 정리 (리소스 관리)
withSqliteEnv :: FilePath -> (SqliteEnv -> IO a) -> IO a
withSqliteEnv dbPath action = do
  conn <- open dbPath
  let env = SqliteEnv conn
  result <- action env
  close conn
  return result

-- | SQLite Row에서 Todo로 변환하는 인스턴스
instance FromRow Todo where
  fromRow =
    Todo
      <$> (fromIntegral <$> (field :: RowParser Int64)) -- todoId
      <*> (toTodoType <$> field) -- todoType (Int로 저장)
      <*> (toTodoStatus <$> field) -- status (Int로 저장)
      <*> field -- description

-- | Todo를 SQLite Row로 변환하는 인스턴스
instance ToRow Todo where
  toRow todo =
    toRow
      ( fromIntegral (_todoId todo) :: Int64
      , fromTodoType (_todoType todo)
      , fromTodoStatus (_status todo)
      , _description todo
      )

-- | Int를 TodoType으로 변환
toTodoType :: Int -> TodoType
toTodoType 0 = Home
toTodoType 1 = Work
toTodoType 2 = Sports
toTodoType _ = Home

-- | TodoType을 Int로 변환
fromTodoType :: TodoType -> Int
fromTodoType Home   = 0
fromTodoType Work   = 1
fromTodoType Sports = 2

-- | Int를 TodoStatus로 변환
toTodoStatus :: Int -> TodoStatus
toTodoStatus 0 = Pending
toTodoStatus 1 = Done
toTodoStatus _ = Pending

-- | TodoStatus를 Int로 변환
fromTodoStatus :: TodoStatus -> Int
fromTodoStatus Pending = 0
fromTodoStatus Done    = 1

-- | MonadTodoRepo 인스턴스 (SQLite 기반 구현)
instance MonadTodoRepo AppM where
  -- \| 모든 할일 목록 조회
  getAllTodos = do
    conn <- asks sqliteConn
    liftIO $ query_ conn "SELECT id, type, status, description FROM todos ORDER BY id DESC"

  -- \| 할일 추가
  insertTodo todo = do
    conn <- asks sqliteConn
    liftIO $ do
      execute
        conn
        "INSERT INTO todos (id, type, status, description) VALUES (?, ?, ?, ?)"
        ( fromIntegral (_todoId todo) :: Int64
        , fromTodoType (_todoType todo)
        , fromTodoStatus (_status todo)
        , _description todo
        )
      return todo

  -- \| 할일 수정
  updateTodo todoId todo = do
    conn <- asks sqliteConn
    liftIO $
      execute
        conn
        "UPDATE todos SET type = ?, status = ?, description = ? WHERE id = ?"
        ( fromTodoType (_todoType todo)
        , fromTodoStatus (_status todo)
        , _description todo
        , fromIntegral todoId :: Int64
        )

  -- \| 할일 삭제
  deleteTodo todoId = do
    conn <- asks sqliteConn
    liftIO $
      execute conn "DELETE FROM todos WHERE id = ?" (Only (fromIntegral todoId :: Int64))

  -- \| 데이터베이스 초기화 (테이블 생성)
  initializeDb = do
    conn <- asks sqliteConn
    liftIO $
      execute_ conn $
        Query $
          T.unlines
            [ "CREATE TABLE IF NOT EXISTS todos ("
            , "  id INTEGER PRIMARY KEY,"
            , "  type INTEGER NOT NULL,"
            , "  status INTEGER NOT NULL,"
            , "  description TEXT NOT NULL"
            , ")"
            ]
