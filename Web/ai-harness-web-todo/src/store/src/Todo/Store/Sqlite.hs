{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings #-}

-- | 'TodoRepository' 포트의 SQLite 구현입니다.
--
-- 도메인은 이 모듈을 알지 못합니다. 의존 방향은 항상
-- @store -> core@ 한 방향이며 @ARCHITECTURE.md@가 이를 규정합니다.
--
-- 저장 형식은 @docs/contracts/data/TODO-STORE-v1.md@에 게시한 데이터 계약을 따릅니다.
-- 시각과 날짜는 문자열로 저장하므로 인코딩과 디코딩이 이 모듈에 모여 있습니다.
module Todo.Store.Sqlite (
  -- * 실행
  SqliteT,
  runSqlite,
  openStore,
  closeStore,
  withStore,

  -- * 오류
  StoreError (..),
) where

import Control.Exception (Exception, throwIO)
import Control.Monad.IO.Class (MonadIO (..))
import Control.Monad.Reader (ReaderT (..), ask)
import Data.Int (Int64)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, UTCTime, getCurrentTime)
import Data.Time.Format.ISO8601 (iso8601ParseM, iso8601Show)
import Database.SQLite.Simple (
  Connection,
  FromRow (..),
  Only (..),
  Query (..),
  changes,
  close,
  execute,
  executeMany,
  field,
  lastInsertRowId,
  open,
  query,
  query_,
  withTransaction,
 )
import Todo.Core.Repository (NewTodo (..), TodoRepository (..))
import Todo.Core.Types (
  ListId (..),
  Priority,
  Status (..),
  Tag (..),
  Title (..),
  Todo (..),
  TodoId (..),
  priorityFromName,
  priorityName,
  statusFromName,
  statusName,
 )
import Todo.Store.Migration (applySchema, configureConnection, withBusyRetry)

-- | 저장된 값을 도메인 값으로 되돌릴 수 없을 때 발생합니다.
--
-- 이 예외는 정상 흐름이 아니라 데이터 손상 신호입니다. 안전한 기본값으로
-- 덮어쓰지 않고 실패시키는 것이 의도된 동작입니다.
newtype StoreError = CorruptedRow Text
  deriving stock (Eq, Show)

instance Exception StoreError

-- | SQLite 연결을 읽기 전용 환경으로 갖는 실행 모나드입니다.
newtype SqliteT m a = SqliteT (ReaderT Connection m a)
  deriving newtype (Functor, Applicative, Monad, MonadIO)

-- | 연결 위에서 저장소 동작을 실행합니다.
runSqlite :: Connection -> SqliteT m a -> m a
runSqlite conn (SqliteT action) = runReaderT action conn

-- | 데이터베이스를 열고 설정과 스키마를 적용합니다.
openStore :: FilePath -> IO Connection
openStore path = do
  conn <- open path
  now <- getCurrentTime
  -- 설정과 스키마 적용을 함께 재시도합니다. 두 표면이 같은 파일을 동시에 처음 열면
  -- 저널 모드 전환에서 경합하며, 그 경합은 busy_timeout이 덮지 못합니다
  -- (@Todo.Store.Migration.withBusyRetry@).
  withBusyRetry $ do
    configureConnection conn
    applySchema conn now
  pure conn

-- | 연결을 닫습니다.
closeStore :: Connection -> IO ()
closeStore = close

-- | 열기와 닫기를 감싼 편의 함수입니다.
withStore :: FilePath -> (Connection -> IO a) -> IO a
withStore path action = do
  conn <- openStore path
  result <- action conn
  closeStore conn
  pure result

-- 행 표현 -------------------------------------------------------------------

data TodoRow = TodoRow
  { rowId :: Int
  , rowTitle :: Text
  , rowListId :: Text
  , rowStatus :: Text
  , rowPriority :: Text
  , rowDueOn :: Maybe Text
  , rowCreatedAt :: Text
  , rowUpdatedAt :: Text
  }

instance FromRow TodoRow where
  fromRow =
    TodoRow
      <$> field
      <*> field
      <*> field
      <*> field
      <*> field
      <*> field
      <*> field
      <*> field

selectColumns :: Text
selectColumns = "id, title, list_id, status, priority, due_on, created_at, updated_at"

-- 인코딩과 디코딩 -------------------------------------------------------------

decodeStatus :: Int -> Text -> IO Status
decodeStatus tid raw = case statusFromName raw of
  Just status -> pure status
  Nothing -> throwIO (CorruptedRow (rowLabel tid <> "알 수 없는 상태: " <> raw))

decodePriority :: Int -> Text -> IO Priority
decodePriority tid raw = case priorityFromName raw of
  Just priority -> pure priority
  Nothing -> throwIO (CorruptedRow (rowLabel tid <> "알 수 없는 우선순위: " <> raw))

decodeDay :: Int -> Text -> IO Day
decodeDay tid raw = case iso8601ParseM (T.unpack raw) of
  Just day -> pure day
  Nothing -> throwIO (CorruptedRow (rowLabel tid <> "날짜 형식 오류: " <> raw))

decodeTime :: Int -> Text -> IO UTCTime
decodeTime tid raw = case iso8601ParseM (T.unpack raw) of
  Just time -> pure time
  Nothing -> throwIO (CorruptedRow (rowLabel tid <> "시각 형식 오류: " <> raw))

rowLabel :: Int -> Text
rowLabel tid = "todos.id=" <> T.pack (show tid) <> ": "

toTodo :: Set Tag -> TodoRow -> IO Todo
toTodo tags row = do
  let tid = rowId row
  status <- decodeStatus tid (rowStatus row)
  priority <- decodePriority tid (rowPriority row)
  dueOn <- traverse (decodeDay tid) (rowDueOn row)
  createdAt <- decodeTime tid (rowCreatedAt row)
  updatedAt <- decodeTime tid (rowUpdatedAt row)
  pure
    Todo
      { todoId = TodoId tid
      , todoTitle = Title (rowTitle row)
      , todoListId = ListId (rowListId row)
      , todoStatus = status
      , todoPriority = priority
      , todoTags = tags
      , todoDueOn = dueOn
      , todoCreatedAt = createdAt
      , todoUpdatedAt = updatedAt
      }

encodeDay :: Day -> Text
encodeDay = T.pack . iso8601Show

encodeTime :: UTCTime -> Text
encodeTime = T.pack . iso8601Show

-- 태그 조회 ------------------------------------------------------------------

tagsFor :: Connection -> Int -> IO (Set Tag)
tagsFor conn tid = do
  rows <- query conn "SELECT tag FROM todo_tags WHERE todo_id = ?" (Only tid)
  pure (Set.fromList [Tag t | Only t <- rows])

allTagsByTodo :: Connection -> IO (Map Int (Set Tag))
allTagsByTodo conn = do
  rows <- query_ conn "SELECT todo_id, tag FROM todo_tags"
  pure (Map.fromListWith Set.union [(tid, Set.singleton (Tag t)) | (tid, t) <- rows])

writeTags :: Connection -> Int -> Set Tag -> IO ()
writeTags conn tid tags = do
  execute conn "DELETE FROM todo_tags WHERE todo_id = ?" (Only tid)
  executeMany
    conn
    "INSERT INTO todo_tags (todo_id, tag) VALUES (?, ?)"
    [(tid, unTag tag) | tag <- Set.toList tags]

-- 포트 구현 ------------------------------------------------------------------

withConnection :: (MonadIO m) => (Connection -> IO a) -> SqliteT m a
withConnection action = SqliteT $ do
  conn <- ask
  liftIO (action conn)

instance (MonadIO m) => TodoRepository (SqliteT m) where
  insertTodo new = withConnection $ \conn -> withTransaction conn $ do
    execute
      conn
      "INSERT INTO todos (title, list_id, status, priority, due_on, created_at, updated_at)\
      \ VALUES (?, ?, ?, ?, ?, ?, ?)"
      ( unTitle (newTitle new)
      , unListId (newListId new)
      , statusName Pending
      , priorityName (newPriority new)
      , encodeDay <$> newDueOn new
      , encodeTime (newCreatedAt new)
      , encodeTime (newCreatedAt new)
      )
    rowid <- lastInsertRowId conn
    let tid = fromIntegral (rowid :: Int64)
    writeTags conn tid (newTags new)
    pure
      Todo
        { todoId = TodoId tid
        , todoTitle = newTitle new
        , todoListId = newListId new
        , todoStatus = Pending
        , todoPriority = newPriority new
        , todoTags = newTags new
        , todoDueOn = newDueOn new
        , todoCreatedAt = newCreatedAt new
        , todoUpdatedAt = newCreatedAt new
        }

  findTodo (TodoId tid) = withConnection $ \conn -> do
    rows <- query conn (selectFrom "WHERE id = ?") (Only tid)
    case rows of
      [] -> pure Nothing
      row : _ -> do
        tags <- tagsFor conn tid
        Just <$> toTodo tags row

  allTodos = withConnection $ \conn -> do
    rows <- query_ conn (selectFrom "ORDER BY id")
    tagMap <- allTagsByTodo conn
    mapM (\row -> toTodo (Map.findWithDefault Set.empty (rowId row) tagMap) row) rows

  replaceTodo todo = withConnection $ \conn -> withTransaction conn $ do
    let TodoId tid = todoId todo
    execute
      conn
      "UPDATE todos SET title = ?, list_id = ?, status = ?, priority = ?,\
      \ due_on = ?, updated_at = ? WHERE id = ?"
      ( unTitle (todoTitle todo)
      , unListId (todoListId todo)
      , statusName (todoStatus todo)
      , priorityName (todoPriority todo)
      , encodeDay <$> todoDueOn todo
      , encodeTime (todoUpdatedAt todo)
      , tid
      )
    affected <- changes conn
    if affected == 0
      then pure False
      else do
        writeTags conn tid (todoTags todo)
        pure True

  removeTodo (TodoId tid) = withConnection $ \conn -> withTransaction conn $ do
    execute conn "DELETE FROM todos WHERE id = ?" (Only tid)
    affected <- changes conn
    pure (affected > 0)

-- | 열 목록을 한 곳에서만 관리하기 위한 도우미입니다.
--
-- 'TodoRow'의 필드 순서와 'selectColumns'의 순서는 반드시 일치해야 합니다.
selectFrom :: Text -> Query
selectFrom rest = Query ("SELECT " <> selectColumns <> " FROM todos " <> rest)
