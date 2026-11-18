{-# LANGUAGE OverloadedStrings #-}

module Infrastructure.SQLiteTaskRepository
  ( newSQLiteTaskRepository
  , seedInitialTasks
  )
where

import Application.Port.TaskRepository (TaskRepository (..))
import Control.Monad (forM, forM_, when)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Typeable (Typeable)
import Database.SQLite.Simple
  ( Connection
  , FromRow (..)
  , Only (..)
  , Query
  , SQLData
  , ToRow (..)
  , changes
  , execute
  , field
  , lastInsertRowId
  , query
  , query_
  , withTransaction
  )
import Database.SQLite.Simple.FromField
  ( FromField (fromField)
  , ResultError (ConversionFailed)
  , returnError
  )
import Database.SQLite.Simple.FromRow (RowParser, fieldWith)
import Database.SQLite.Simple.ToField (toField)
import Domain.Task
  ( Outcome (..)
  , OutcomeInput (..)
  , OutcomeOwner (..)
  , Status
  , TaskError (..)
  , TaskItem (..)
  , TaskOwner (..)
  , assembleOutcome
  , createTask
  , taskId
  , updateTask
  )
import Infrastructure.SQLiteDatabase
  ( SQLiteDatabase
  , withSQLiteConnection
  )
import Text.Read (readMaybe)

newtype Parameters = Parameters [SQLData]

instance ToRow Parameters where
  toRow (Parameters values) = values

data OutcomeRow = OutcomeRow Int Text Text Status

newtype TaskRow = TaskRow {fromTaskRow :: TaskItem}

instance FromRow TaskRow where
  fromRow =
    TaskRow
      <$> ( TaskItem
              <$> field
              <*> field
              <*> field
              <*> readEnum "task status"
              <*> readEnum "task urgency"
              <*> readEnum "task importance"
              <*> (TaskOwner <$> field)
              <*> (OutcomeOwner <$> field)
              <*> field
              <*> field
              <*> field
          )

instance FromRow OutcomeRow where
  fromRow = OutcomeRow <$> field <*> field <*> field <*> readEnum "outcome status"

newSQLiteTaskRepository :: SQLiteDatabase -> IO (TaskRepository IO)
newSQLiteTaskRepository database =
  pure
    TaskRepository
      { listTasks = withSQLiteConnection database queryAllTasks
      , findTask = \identifier ->
          withSQLiteConnection database $ \connection -> do
            rows <- query connection taskSelectById (Only identifier)
            pure (fromTaskRow <$> firstOrNothing rows)
      , createStoredTask = \input ->
          withSQLiteConnection database $ \connection -> do
            let task = createTask 0 input
            execute connection taskInsert (taskParameters task)
            identifier <- fromIntegral <$> lastInsertRowId connection
            pure task {taskId = identifier}
      , updateStoredTask = \identifier input ->
          withSQLiteConnection database $ \connection -> do
            rows <- query connection taskSelectById (Only identifier)
            case firstOrNothing rows of
              Nothing -> pure Nothing
              Just (TaskRow existing) -> do
                let updated = updateTask existing input
                execute connection taskUpdate (updateParameters updated)
                pure (Just updated)
      , replaceStoredTask = \task ->
          withSQLiteConnection database $ \connection ->
            execute connection taskUpdate (updateParameters task)
      , deleteStoredTask = \identifier ->
          withSQLiteConnection database $ \connection -> do
            execute connection "DELETE FROM tasks WHERE id = ?" (Only identifier)
            (> 0) <$> changes connection
      , listOutcomes = withSQLiteConnection database queryAllOutcomes
      , createStoredOutcome = \input ->
          withSQLiteConnection database $ \connection ->
            withTransaction connection (createOutcome connection input)
      }

seedInitialTasks :: SQLiteDatabase -> [TaskItem] -> IO ()
seedInitialTasks database tasks =
  withSQLiteConnection database $ \connection ->
    withTransaction connection $ do
      marker <-
        query_
          connection
          "SELECT value FROM app_metadata WHERE key = 'seed.initial_tasks.v1'"
          :: IO [Only Text]
      when (null marker) $ do
        [Only taskCount] <- query_ connection "SELECT COUNT(*) FROM tasks" :: IO [Only Int]
        when (taskCount == 0) $
          forM_ tasks $ \task ->
            execute connection taskInsertWithId (seedParameters task)
        execute
          connection
          "INSERT INTO app_metadata (key, value) VALUES ('seed.initial_tasks.v1', ?)"
          (Only (if taskCount == 0 then ("inserted" :: Text) else "skipped"))

createOutcome :: Connection -> OutcomeInput -> IO (Either TaskError Outcome)
createOutcome connection input = do
  storedTasks <- queryAllTasks connection
  let selectedTasks =
        filter (\task -> taskId task `elem` inputSourceTaskIds input) storedTasks
  if length selectedTasks /= length (inputSourceTaskIds input)
    then pure (Left TaskNotApproved)
    else case assembleOutcome 0 input selectedTasks of
      Left err -> pure (Left err)
      Right candidate -> do
        execute
          connection
          "INSERT INTO outcomes (description, outcome_owner, status) VALUES (?, ?, ?)"
          ( outcomeDescription candidate
          , unwrapOutcomeOwner (outcomeOwner candidate)
          , enumText (outcomeStatus candidate)
          )
        identifier <- fromIntegral <$> lastInsertRowId connection
        forM_ (zip [0 :: Int ..] (sourceTaskIds candidate)) $ \(position, sourceId) ->
          execute
            connection
            "INSERT INTO outcome_task_ids (outcome_id, position, task_id) VALUES (?, ?, ?)"
            (identifier, position, sourceId)
        forM_ (zip [0 :: Int ..] (outcomeResults candidate)) $ \(position, result) ->
          execute
            connection
            "INSERT INTO outcome_results (outcome_id, position, result) VALUES (?, ?, ?)"
            (identifier, position, result)
        pure (Right candidate {outcomeId = identifier})

queryAllTasks :: Connection -> IO [TaskItem]
queryAllTasks connection = map fromTaskRow <$> query_ connection taskSelectAll

queryAllOutcomes :: Connection -> IO [Outcome]
queryAllOutcomes connection = withTransaction connection $ do
  rows <-
    query_
      connection
      "SELECT id, description, outcome_owner, status FROM outcomes ORDER BY id"
  forM rows $ \(OutcomeRow identifier descriptionText owner parsedStatus) -> do
    taskIds <-
      query
        connection
        "SELECT task_id FROM outcome_task_ids WHERE outcome_id = ? ORDER BY position"
        (Only identifier)
    results <-
      query
        connection
        "SELECT result FROM outcome_results WHERE outcome_id = ? ORDER BY position"
        (Only identifier)
    pure
      Outcome
        { outcomeId = identifier
        , outcomeDescription = descriptionText
        , outcomeOwner = OutcomeOwner owner
        , sourceTaskIds = map fromOnly taskIds
        , outcomeResults = map fromOnly results
        , outcomeStatus = parsedStatus
        }

taskSelectAll :: Query
taskSelectAll =
  "SELECT id, title, description, status, urgency, importance, task_owner, outcome_owner, expected_result, submitted_result, review_comment FROM tasks ORDER BY id"

taskSelectById :: Query
taskSelectById =
  "SELECT id, title, description, status, urgency, importance, task_owner, outcome_owner, expected_result, submitted_result, review_comment FROM tasks WHERE id = ?"

taskInsert :: Query
taskInsert =
  "INSERT INTO tasks (title, description, status, urgency, importance, task_owner, outcome_owner, expected_result, submitted_result, review_comment) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"

taskInsertWithId :: Query
taskInsertWithId =
  "INSERT INTO tasks (id, title, description, status, urgency, importance, task_owner, outcome_owner, expected_result, submitted_result, review_comment) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"

taskUpdate :: Query
taskUpdate =
  "UPDATE tasks SET title = ?, description = ?, status = ?, urgency = ?, importance = ?, task_owner = ?, outcome_owner = ?, expected_result = ?, submitted_result = ?, review_comment = ? WHERE id = ?"

taskParameters :: TaskItem -> Parameters
taskParameters task =
  Parameters
    [ toField (title task)
    , toField (description task)
    , toField (enumText (status task))
    , toField (enumText (urgency task))
    , toField (enumText (importance task))
    , toField (unwrapTaskOwner (taskOwner task))
    , toField (unwrapOutcomeOwner (reviewOwner task))
    , toField (expectedResult task)
    , toField (submittedResult task)
    , toField (reviewComment task)
    ]

seedParameters :: TaskItem -> Parameters
seedParameters task =
  case taskParameters task of
    Parameters values -> Parameters (toField (taskId task) : values)

updateParameters :: TaskItem -> Parameters
updateParameters task =
  case taskParameters task of
    Parameters values -> Parameters (values <> [toField (taskId task)])

enumText :: (Show a) => a -> Text
enumText = Text.pack . show

unwrapTaskOwner :: TaskOwner -> Text
unwrapTaskOwner (TaskOwner owner) = owner

unwrapOutcomeOwner :: OutcomeOwner -> Text
unwrapOutcomeOwner (OutcomeOwner owner) = owner

readEnum :: (Read a, Typeable a) => String -> RowParser a
readEnum label = fieldWith $ \storedField -> do
  value <- fromField storedField
  maybe
    ( returnError
        ConversionFailed
        storedField
        ("invalid " <> label <> " stored in SQLite: " <> Text.unpack value)
    )
    pure
    (readMaybe (Text.unpack value))

firstOrNothing :: [a] -> Maybe a
firstOrNothing [] = Nothing
firstOrNothing (value : _) = Just value
