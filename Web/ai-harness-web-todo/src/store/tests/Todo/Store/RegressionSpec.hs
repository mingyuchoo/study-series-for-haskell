{-# LANGUAGE OverloadedStrings #-}

-- | 과거 사고의 최소 재현과 조치 검증입니다.
--
-- @docs/incidents/INC-2026-001.md@에서 CLI와 HTTP API가 같은 파일에 동시에 쓸 때
-- @SQLITE_BUSY@로 명령이 실패했습니다. 조치는 WAL 모드와 busy timeout이며
-- (@docs/incidents/lessons.md@의 @LESSON-001@) 이 파일이 그 조치를 고정합니다.
--
-- 그 사고의 교훈은 저널 모드 자체가 아니라 __제품이 약속한 사용 방식이 테스트되지
-- 않으면 그 약속이 언젠가 깨진다__는 것이었습니다. 사고 당시 표면은 둘이었고 테스트도
-- 둘이었습니다. 지금은 @web@이 더해져 셋이므로 여기도 셋입니다
-- (@docs/decisions/ADR-0004-web-surface.md@).
module Todo.Store.RegressionSpec (spec) where

import Control.Concurrent (forkIO)
import Control.Concurrent.MVar (newEmptyMVar, putMVar, takeMVar)
import Control.Exception (SomeException, throwIO, try)
import Data.Either (isRight)
import Data.IORef (atomicModifyIORef', newIORef, readIORef)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime (..), fromGregorian, secondsToDiffTime)
import Database.SQLite.Simple (Connection, Error (..), Only (..), SQLError (..), query_)
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.Hspec (Spec, describe, it, shouldBe)
import Todo.Core.Repository (NewTodo (..), TodoRepository (..))
import Todo.Core.Types (ListId (..), Priority (..), Title (..))
import Todo.Store.Migration (withBusyRetry)
import Todo.Store.Sqlite (openStore, runSqlite, withStore)

fixedNow :: UTCTime
fixedNow = UTCTime (fromGregorian 2026 8 22) (secondsToDiffTime 0)

newTodoNamed :: Text -> NewTodo
newTodoNamed title =
  NewTodo
    { newTitle = Title title
    , newListId = ListId "inbox"
    , newPriority = Normal
    , newTags = Set.empty
    , newDueOn = Nothing
    , newCreatedAt = fixedNow
    }

-- | 사고 당시 동시 쓰기 규모를 테스트가 감당할 크기로 줄인 값입니다.
writesPerWriter :: Int
writesPerWriter = 25

-- | 브라우저 탭을 열어 둔 상태를 흉내 내는 읽기 횟수입니다.
readsPerReader :: Int
readsPerReader = 25

writeSeries :: Connection -> Text -> IO ()
writeSeries conn prefix =
  mapM_
    (\i -> runSqlite conn (insertTodo (newTodoNamed (prefix <> T.pack (show i)))))
    [1 .. writesPerWriter]

-- | 열기와 첫 쓰기를 한 동작으로 묶습니다. 여는 순간의 경합을 재현하려면 세 표면이
-- 같은 시점에 @openStore@를 호출해야 합니다.
openAndInsert :: FilePath -> Text -> IO ()
openAndInsert path prefix = do
  conn <- openStore path
  _ <- runSqlite conn (insertTodo (newTodoNamed prefix))
  pure ()

readSeries :: Connection -> IO ()
readSeries conn = mapM_ (\_ -> runSqlite conn allTodos) [1 .. readsPerReader]

-- | 여러 동작을 동시에 실행하고 각각의 성공 여부를 돌려줍니다.
concurrently_ :: [IO ()] -> IO [Bool]
concurrently_ actions = do
  slots <- mapM (const newEmptyMVar) actions
  mapM_
    (\(action, slot) -> forkIO (try action >>= \outcome -> putMVar slot (outcome :: Either SomeException ())))
    (zip actions slots)
  map isRight <$> mapM takeMVar slots

spec :: Spec
spec = describe "INC-2026-001 회귀" $ do
  it "연결은 WAL 저널 모드를 사용한다" $ do
    modes <- withSystemTempDirectory "store-wal" $ \dir ->
      withStore (dir </> "todo.db") $ \conn ->
        query_ conn "PRAGMA journal_mode"
    map fromOnly modes `shouldBe` ["wal" :: Text]

  it "두 표면이 같은 파일을 동시에 처음 열어도 실패하지 않는다" $
    -- 기존 회귀 테스트는 연결을 차례로 연 뒤의 쓰기만 다루었습니다. 두 서버를 한
    -- 명령으로 함께 띄우면서 드러난 것은 __여는 순간__의 경합입니다. WAL 전환은
    -- 배타적 잠금을 요구하므로, busy timeout이 아직 적용되지 않았다면 즉시 실패합니다.
    withSystemTempDirectory "store-open-race" $ \dir -> do
      let path = dir </> "todo.db"
      -- 파일이 없는 상태에서 시작합니다. 스키마 생성까지 함께 경합해야 합니다.
      outcomes <-
        concurrently_
          [ openAndInsert path "web"
          , openAndInsert path "api"
          , openAndInsert path "cli"
          ]

      outcomes `shouldBe` [True, True, True]

      conn <- openStore path
      stored <- runSqlite conn allTodos
      length stored `shouldBe` 3

  it "세 표면이 같은 파일에 동시에 써도 잠금 오류로 실패하지 않는다" $
    withSystemTempDirectory "store-concurrent" $ \dir -> do
      let path = dir </> "todo.db"
      -- 표면 하나가 연결 하나를 엽니다. 이름을 실제 패키지 이름으로 둔 것은 이
      -- 테스트가 흉내 내는 상황을 분명히 하기 위해서입니다.
      cli <- openStore path
      api <- openStore path
      web <- openStore path

      outcomes <-
        concurrently_
          [ writeSeries cli "cli-"
          , writeSeries api "api-"
          , writeSeries web "web-"
          ]

      outcomes `shouldBe` [True, True, True]

      stored <- runSqlite cli allTodos
      length stored `shouldBe` writesPerWriter * 3

  it "브라우저 탭이 계속 읽는 동안에도 다른 표면이 쓸 수 있다" $
    -- web은 탭을 열어 두면 연결을 상시 유지합니다. CLI 중심 사용에는 없던
    -- 패턴이며, WAL에서 읽기가 쓰기를 막지 않는다는 전제에 의존합니다.
    withSystemTempDirectory "store-reader" $ \dir -> do
      let path = dir </> "todo.db"
      web <- openStore path
      cli <- openStore path
      api <- openStore path

      outcomes <-
        concurrently_
          [ readSeries web
          , writeSeries cli "cli-"
          , writeSeries api "api-"
          ]

      outcomes `shouldBe` [True, True, True]

      -- 읽던 연결에서도 새로 쓰인 값이 보여야 합니다. 세 표면이 같은 확정 상태를
      -- 본다는 PROD-INV-003의 저장 계층 근거입니다.
      seen <- runSqlite web allTodos
      length seen `shouldBe` writesPerWriter * 2

  describe "기동 경합 재시도" $ do
    -- busy_timeout이 모든 경합을 덮지 않습니다. 저널 모드를 WAL로 바꾸는 일은
    -- 배타적 잠금을 요구하면서도 busy handler를 거치지 않고 즉시 SQLITE_BUSY를
    -- 돌려줍니다. 빈 데이터베이스를 두 프로세스가 동시에 처음 열면 그 지점에서
    -- 실패하며, 이는 두 표면을 함께 띄우는 설계에서 정상 경로입니다.
    --
    -- 프로세스 간 경합 자체는 한 테스트 프로세스 안에서 재현되지 않습니다. 같은
    -- 프로세스의 연결들은 SQLite 내부에서 직렬화되어 경합이 가려집니다. 따라서
    -- 여기서는 재시도 기제를 직접 검증하고, 실제 경합은 수동 확인으로 남깁니다
    -- (`../../docs/architecture.md`).
    it "SQLITE_BUSY로 실패한 동작을 다시 시도한다" $ do
      remaining <- newIORef (3 :: Int)
      value <- withBusyRetry $ do
        left <- atomicModifyIORef' remaining (\n -> (max 0 (n - 1), n))
        if left > 0 then throwIO (busyError "database is locked") else pure "성공"
      value `shouldBe` ("성공" :: String)
      readIORef remaining >>= (`shouldBe` 0)

    it "SQLITE_LOCKED도 재시도 대상이다" $ do
      tried <- newIORef (2 :: Int)
      value <- withBusyRetry $ do
        left <- atomicModifyIORef' tried (\n -> (max 0 (n - 1), n))
        if left > 0
          then throwIO ((busyError "table is locked"){sqlError = ErrorLocked})
          else pure ("성공" :: String)
      value `shouldBe` "성공"

    it "다른 오류는 재시도하지 않고 그대로 올린다" $ do
      calls <- newIORef (0 :: Int)
      outcome <-
        try
          ( withBusyRetry $ do
              _ <- atomicModifyIORef' calls (\n -> (n + 1, n))
              throwIO ((busyError "no such table"){sqlError = ErrorError})
          )
          :: IO (Either SQLError ())
      isRight outcome `shouldBe` False
      -- 한 번만 시도해야 합니다. 재시도하면 실패를 늦게 알리게 됩니다.
      readIORef calls >>= (`shouldBe` 1)

    it "재시도가 무한하지 않고 원래 오류를 올린다" $ do
      calls <- newIORef (0 :: Int)
      outcome <-
        try
          ( withBusyRetry $ do
              _ <- atomicModifyIORef' calls (\n -> (n + 1, n))
              throwIO (busyError "database is locked")
                :: IO ()
          )
          :: IO (Either SQLError ())
      isRight outcome `shouldBe` False
      attempts <- readIORef calls
      attempts `shouldBe` 11

-- | 재시도 대상인 잠금 오류를 흉내 냅니다.
busyError :: Text -> SQLError
busyError detail =
  SQLError
    { sqlError = ErrorBusy
    , sqlErrorDetails = detail
    , sqlErrorContext = "테스트"
    }
