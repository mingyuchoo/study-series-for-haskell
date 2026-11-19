module RepositorySpec (spec) where

import Control.Exception (bracket)
import DB qualified
import Database.SQLite.Simple (Connection, close, execute_, open)
import Infrastructure.Repository (sqliteRepository)
import Test.Hspec hiding (after, before)
import Todo.Application.Repository
import Todo.Application.Workflow
import Todo.Domain.Model qualified as Domain
import TodoStatus

withDatabase :: (Connection -> IO a) -> IO a
withDatabase = bracket (open ":memory:") close . (\run conn -> DB.initDB conn >> run conn)

fields :: Domain.TodoFields
fields =
  either (error . show) id $
    Domain.validateFields "created" (Just " subject ") Nothing Nothing

spec :: Spec
spec = describe "SQLite workflow repository" $ do
  it "loads typed todos" $ withDatabase $ \conn -> do
    result <- runCommand (sqliteRepository conn) LoadTodos
    case result of
      Succeeded (TodosLoaded todos) -> length todos `shouldBe` 3
      actual -> expectationFailure $ show actual
  it "creates and reads confirmed normalized fields" $ withDatabase $ \conn -> do
    result <- runCommand (sqliteRepository conn) $ InsertTodo fields
    case result of
      Succeeded (TodoCreated todo) -> do
        Domain.fields todo `shouldBe` fields
        Domain.status todo `shouldBe` Registered
        Domain.createdAt todo `shouldSatisfy` (not . null)
      actual -> expectationFailure $ show actual
  it "updates fields without changing status" $ withDatabase $ \conn -> do
    target <- DB.createTodo conn "original"
    result <- runCommand (sqliteRepository conn) $ UpdateFields target fields
    case result of
      Succeeded (TodoUpdated todo) -> do
        Domain.identifier todo `shouldBe` target
        Domain.fields todo `shouldBe` fields
        Domain.status todo `shouldBe` Registered
      actual -> expectationFailure $ show actual
  it "deletes the requested row" $ withDatabase $ \conn -> do
    target <- DB.createTodo conn "delete"
    result <- runCommand (sqliteRepository conn) $ RemoveTodo target
    result `shouldBe` Succeeded (TodoDeleted target)
    rows <- DB.getAllTodos conn
    map DB.todoId rows `shouldNotContain` [target]
  it "reports a missing update target" $ withDatabase $ \conn -> do
    result <- runCommand (sqliteRepository conn) $ UpdateFields 999 fields
    result `shouldBe` Rejected (MissingTodo 999)
  it "reports a missing delete target" $ withDatabase $ \conn -> do
    result <- runCommand (sqliteRepository conn) $ RemoveTodo 999
    result `shouldBe` Rejected (MissingTodo 999)
  it "cycles the complete status machine with confirmed timestamps" $ withDatabase $ \conn -> do
    target <- DB.createTodo conn "cycle"
    mapM_
      ( \(before, after) -> do
          result <- runCommand (sqliteRepository conn) $ SetStatus target before after
          case result of
            Succeeded (StatusChanged todo) -> do
              Domain.status todo `shouldBe` after
              Domain.changedAt todo `shouldSatisfy` (/= Nothing)
            actual -> expectationFailure $ show actual
      )
      [ (Registered, InProgress)
      , (InProgress, Cancelled)
      , (Cancelled, Completed)
      , (Completed, Registered)
      ]
  it "rejects a stale status change" $ withDatabase $ \conn -> do
    target <- DB.createTodo conn "stale"
    result <- runCommand (sqliteRepository conn) $ SetStatus target InProgress Cancelled
    result `shouldBe` Rejected (StaleStatus target)
  it "rejects unknown stored statuses" $ withDatabase $ \conn -> do
    execute_ conn "UPDATE todos SET status = 'corrupt' WHERE id = 1"
    result <- runCommand (sqliteRepository conn) LoadTodos
    result `shouldBe` Rejected (InvalidStoredStatus 1 "corrupt")
  it "rolls back a create if readback fails" $ withDatabase $ \conn -> do
    execute_
      conn
      "CREATE TRIGGER corrupt_insert AFTER INSERT ON todos BEGIN UPDATE todos SET status = 'corrupt' WHERE id = new.id; END"
    before <- DB.getAllTodos conn
    result <- runCommand (sqliteRepository conn) $ InsertTodo fields
    case result of
      Rejected (InvalidStoredStatus _ "corrupt") -> pure ()
      actual -> expectationFailure $ show actual
    DB.getAllTodos conn `shouldReturn` before
  it "rolls back an update if readback fails" $ withDatabase $ \conn -> do
    target <- DB.createTodo conn "unchanged"
    execute_
      conn
      "CREATE TRIGGER corrupt_update AFTER UPDATE OF text ON todos BEGIN UPDATE todos SET status = 'corrupt' WHERE id = new.id; END"
    before <- DB.getAllTodos conn
    result <- runCommand (sqliteRepository conn) $ UpdateFields target fields
    result `shouldBe` Rejected (InvalidStoredStatus target "corrupt")
    DB.getAllTodos conn `shouldReturn` before
  it "turns synchronous database failures into rejected events" $ do
    conn <- open ":memory:"
    close conn
    result <- runCommand (sqliteRepository conn) LoadTodos
    case result of
      Rejected (RepositoryFailure _) -> pure ()
      actual -> expectationFailure $ show actual

  it "rejects ignored insertions instead of reporting an unrelated row" $ withDatabase $ \conn -> do
    execute_
      conn
      "CREATE TRIGGER ignore_insert BEFORE INSERT ON todos BEGIN SELECT RAISE(IGNORE); END"
    result <- runCommand (sqliteRepository conn) $ InsertTodo fields
    result `shouldBe` Rejected WriteNotApplied
  it "rejects ignored updates instead of reporting stale data as saved" $ withDatabase $ \conn -> do
    target <- DB.createTodo conn "original"
    execute_
      conn
      "CREATE TRIGGER ignore_update BEFORE UPDATE ON todos BEGIN SELECT RAISE(IGNORE); END"
    result <- runCommand (sqliteRepository conn) $ UpdateFields target fields
    result `shouldBe` Rejected WriteNotApplied
  it "rejects ignored deletions instead of hiding a stored row" $ withDatabase $ \conn -> do
    target <- DB.createTodo conn "original"
    execute_
      conn
      "CREATE TRIGGER ignore_delete BEFORE DELETE ON todos BEGIN SELECT RAISE(IGNORE); END"
    result <- runCommand (sqliteRepository conn) $ RemoveTodo target
    result `shouldBe` Rejected WriteNotApplied
