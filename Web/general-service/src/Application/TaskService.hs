module Application.TaskService
  ( createTask
  , createOutcome
  , deleteTask
  , listTasks
  , listOutcomes
  , submitTaskResult
  , approveTaskResult
  , requestTaskRevision
  , updateTask
  )
where

import Application.Port.TaskRepository (TaskRepository)
import qualified Application.Port.TaskRepository as Repository
import Data.Text (Text)
import Domain.Task
  ( Outcome
  , OutcomeInput
  , OutcomeOwner
  , TaskError
  , TaskInput
  , TaskItem
  , TaskOwner
  , validateTaskInput
  )
import qualified Domain.Task as Domain

listTasks :: TaskRepository m -> m [TaskItem]
listTasks = Repository.listTasks

listOutcomes :: TaskRepository m -> m [Outcome]
listOutcomes = Repository.listOutcomes

createTask
  :: (Applicative m) => TaskRepository m -> TaskInput -> m (Either TaskError TaskItem)
createTask repository input =
  case validateTaskInput input of
    Left err -> pure (Left err)
    Right validInput -> Right <$> Repository.createStoredTask repository validInput

updateTask
  :: (Applicative m)
  => TaskRepository m -> Int -> TaskInput -> m (Either TaskError (Maybe TaskItem))
updateTask repository identifier input =
  case validateTaskInput input of
    Left err -> pure (Left err)
    Right validInput -> Right <$> Repository.updateStoredTask repository identifier validInput

deleteTask :: TaskRepository m -> Int -> m Bool
deleteTask = Repository.deleteStoredTask

submitTaskResult
  :: TaskRepository IO -> Int -> TaskOwner -> Text -> IO (Either TaskError (Maybe TaskItem))
submitTaskResult repository identifier actor taskResult = do
  found <- Repository.findTask repository identifier
  case found of
    Nothing -> pure (Right Nothing)
    Just task ->
      case Domain.submitTaskResult actor taskResult task of
        Left err -> pure (Left err)
        Right updated -> do
          Repository.replaceStoredTask repository updated
          pure (Right (Just updated))

approveTaskResult
  :: TaskRepository IO
  -> Int
  -> OutcomeOwner
  -> Maybe Text
  -> IO (Either TaskError (Maybe TaskItem))
approveTaskResult repository identifier actor comment = do
  found <- Repository.findTask repository identifier
  case found of
    Nothing -> pure (Right Nothing)
    Just task ->
      case Domain.approveTaskResult actor comment task of
        Left err -> pure (Left err)
        Right updated -> do
          Repository.replaceStoredTask repository updated
          pure (Right (Just updated))

requestTaskRevision
  :: TaskRepository IO -> Int -> OutcomeOwner -> Text -> IO (Either TaskError (Maybe TaskItem))
requestTaskRevision repository identifier actor comment = do
  found <- Repository.findTask repository identifier
  case found of
    Nothing -> pure (Right Nothing)
    Just task ->
      case Domain.requestTaskRevision actor comment task of
        Left err -> pure (Left err)
        Right updated -> do
          Repository.replaceStoredTask repository updated
          pure (Right (Just updated))

createOutcome
  :: TaskRepository IO -> OutcomeInput -> IO (Either TaskError Outcome)
createOutcome = Repository.createStoredOutcome
