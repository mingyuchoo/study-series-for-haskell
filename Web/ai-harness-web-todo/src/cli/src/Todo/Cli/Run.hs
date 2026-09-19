{-# LANGUAGE OverloadedStrings #-}

-- | 명령을 유스케이스 호출로 옮기는 어댑터입니다.
--
-- 여기서 하는 일은 세 가지뿐입니다.
--
-- 1. 문자열 입력을 "Todo.Core.Validation"으로 도메인 값으로 만듭니다.
-- 2. 시각과 오늘 날짜를 읽어 경계에서 주입합니다.
-- 3. 결과를 출력하고 종료 코드를 정합니다.
--
-- 상태 전이 규칙이나 조회 규칙을 여기서 다시 구현하지 않습니다.
module Todo.Cli.Run (
  runCli,
  resolveDatabasePath,
  defaultDatabasePath,
  databaseEnvVar,
) where

import Control.Monad (unless)
import Data.Maybe (fromMaybe)
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import Data.Time (Day, UTCTime, getCurrentTime, utctDay)
import Database.SQLite.Simple (Connection)
import System.Environment (lookupEnv)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)
import Todo.Cli.Options (
  AddOptions (..),
  Command (..),
  EditOptions (..),
  ListOptions (..),
  Options (..),
 )
import Todo.Cli.Render (renderTodoList, renderUseCaseError)
import Todo.Core.Filter (
  TodoFilter (..),
  emptyFilter,
  resolveStatusFilter,
 )
import Todo.Core.Repository (NewTodo (..), TodoPatch (..), emptyPatch)
import Todo.Core.Types (ListId, Tag, Todo (..), TodoId (..), defaultListId)
import Todo.Core.UseCase (
  StatusChange (..),
  UseCaseError,
  addTodo,
  archiveTodo,
  completeTodo,
  deleteTodo,
  listTodos,
  reopenTodo,
  startTodo,
  updateTodo,
 )
import Todo.Core.Validation (
  ValidationError,
  mkListId,
  mkTags,
  mkTitle,
  renderValidationError,
  validateDueOn,
 )
import Todo.Store.Sqlite (SqliteT, openStore, runSqlite)

-- | 데이터베이스 경로를 지정하는 환경 변수 이름입니다.
databaseEnvVar :: String
databaseEnvVar = "TODO_DB"

-- | 옵션과 환경 변수가 모두 없을 때 사용하는 경로입니다.
defaultDatabasePath :: FilePath
defaultDatabasePath = "todo.db"

-- | @--db@, 환경 변수, 기본값 순으로 경로를 정합니다.
resolveDatabasePath :: Maybe FilePath -> IO FilePath
resolveDatabasePath (Just path) = pure path
resolveDatabasePath Nothing = do
  fromEnv <- lookupEnv databaseEnvVar
  pure (fromMaybe defaultDatabasePath fromEnv)

-- | 명령 하나를 실행합니다.
runCli :: Options -> IO ()
runCli options = do
  path <- resolveDatabasePath (optDatabase options)
  conn <- openStore path
  now <- getCurrentTime
  dispatch conn now (optCommand options)

dispatch :: Connection -> UTCTime -> Command -> IO ()
dispatch conn now cmd = case cmd of
  CmdAdd opts -> runAdd conn now opts
  CmdList opts -> runList conn opts
  CmdStart tid -> runStatus conn (startTodo now) tid
  CmdDone tid -> runStatus conn (completeTodo now) tid
  CmdReopen tid -> runStatus conn (reopenTodo now) tid
  CmdArchive tid -> runStatus conn (archiveTodo now) tid
  CmdRemove tid -> runRemove conn tid
  CmdEdit tid opts -> runEdit conn now tid opts

-- 개별 명령 -----------------------------------------------------------------

runAdd :: Connection -> UTCTime -> AddOptions -> IO ()
runAdd conn now opts = do
  let today = utctDay now
  new <- orAbort (buildNewTodo now today opts)
  todo <- runSqlite conn (addTodo new)
  TIO.putStrLn ("추가했습니다: " <> T.pack (show (unTodoId (todoId todo))))

buildNewTodo :: UTCTime -> Day -> AddOptions -> Either ValidationError NewTodo
buildNewTodo now today opts = do
  title <- mkTitle (addTitle opts)
  listId <- resolveListId (addList opts)
  tags <- mkTags (addTags opts)
  dueOn <- validateDueOn today (addDue opts)
  pure
    NewTodo
      { newTitle = title
      , newListId = listId
      , newPriority = addPriority opts
      , newTags = tags
      , newDueOn = dueOn
      , newCreatedAt = now
      }

runList :: Connection -> ListOptions -> IO ()
runList conn opts = do
  todoFilter <- orAbort (buildFilter opts)
  todos <- runSqlite conn (listTodos todoFilter (listSort opts))
  TIO.putStrLn (renderTodoList todos)

buildFilter :: ListOptions -> Either ValidationError TodoFilter
buildFilter opts = do
  tags <- mkTags (listTags opts)
  listId <- traverse mkListId (listList opts)
  pure
    emptyFilter
      { filterStatus = resolveStatusFilter (listStatus opts) (listAll opts)
      , filterTags = tags
      , filterListId = listId
      , filterDueOnOrBefore = listDueOnOrBefore opts
      }

-- | 상태 변경 명령들이 공유하는 실행 경로입니다.
--
-- 이미 목표 상태였던 경우를 오류가 아니라 무변경으로 알립니다.
runStatus
  :: Connection
  -> (TodoId -> SqliteT IO (Either UseCaseError StatusChange))
  -> Int
  -> IO ()
runStatus conn action rawId = do
  result <- runSqlite conn (action (TodoId rawId))
  case result of
    Left err -> abort (renderUseCaseError err)
    Right change -> do
      unless (statusWasChanged change) $
        TIO.putStrLn "이미 같은 상태여서 아무것도 바꾸지 않았습니다."
      TIO.putStrLn (renderTodoList [changedTodo change])

runRemove :: Connection -> Int -> IO ()
runRemove conn rawId = do
  result <- runSqlite conn (deleteTodo (TodoId rawId))
  case result of
    Left err -> abort (renderUseCaseError err)
    Right () -> TIO.putStrLn ("삭제했습니다: " <> T.pack (show rawId))

runEdit :: Connection -> UTCTime -> Int -> EditOptions -> IO ()
runEdit conn now rawId opts = do
  patch <- orAbort (buildPatch opts)
  result <- runSqlite conn (updateTodo now patch (TodoId rawId))
  case result of
    Left err -> abort (renderUseCaseError err)
    Right todo -> TIO.putStrLn (renderTodoList [todo])

buildPatch :: EditOptions -> Either ValidationError TodoPatch
buildPatch opts = do
  title <- traverse mkTitle (editTitle opts)
  listId <- traverse mkListId (editList opts)
  tags <- editTagPatch opts
  pure
    emptyPatch
      { patchTitle = title
      , patchListId = listId
      , patchPriority = editPriority opts
      , patchTags = tags
      , patchDueOn = duePatch opts
      }

editTagPatch :: EditOptions -> Either ValidationError (Maybe (Set Tag))
editTagPatch opts
  | editClearTags opts = Right (Just Set.empty)
  | null (editTags opts) = Right Nothing
  | otherwise = Just <$> mkTags (editTags opts)

-- | 마감일은 바꾸지 않는 것과 지우는 것을 구분해야 하므로 이중 'Maybe'를 씁니다.
duePatch :: EditOptions -> Maybe (Maybe Day)
duePatch opts
  | editClearDue opts = Just Nothing
  | otherwise = fmap Just (editDue opts)

resolveListId :: Maybe Text -> Either ValidationError ListId
resolveListId Nothing = Right defaultListId
resolveListId (Just raw) = mkListId raw

-- 오류 처리 -----------------------------------------------------------------

-- | 검증 오류를 표준 오류로 출력하고 실패 종료합니다.
orAbort :: Either ValidationError a -> IO a
orAbort (Right value) = pure value
orAbort (Left err) = abort (renderValidationError err)

abort :: Text -> IO a
abort message = do
  hPutStrLn stderr (T.unpack message)
  exitFailure
