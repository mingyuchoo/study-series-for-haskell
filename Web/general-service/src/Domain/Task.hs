module Domain.Task
  ( Status (..)
  , Urgency (..)
  , Importance (..)
  , Quadrant (..)
  , TaskOwner (..)
  , OutcomeOwner (..)
  , TaskItem (..)
  , TaskInput (..)
  , Outcome (..)
  , OutcomeInput (..)
  , TaskError (..)
  , createTask
  , updateTask
  , submitTaskResult
  , approveTaskResult
  , requestTaskRevision
  , assembleOutcome
  , toQuadrant
  , quadrantOf
  , validateTaskInput
  )
where

import Data.Maybe (isNothing)
import Data.Text (Text)
import qualified Data.Text as Text

data Status = Draft | Reviewed | Submitted | Approved | Effective
  deriving (Eq, Show, Read, Enum, Bounded)

data Urgency = Urgent | NotUrgent
  deriving (Eq, Show, Read, Enum, Bounded)

data Importance = Important | NotImportant
  deriving (Eq, Show, Read, Enum, Bounded)

data Quadrant = DoFirst | Schedule | Delegate | Eliminate
  deriving (Eq, Show, Read, Enum, Bounded)

newtype TaskOwner = TaskOwner Text
  deriving (Eq, Show)

newtype OutcomeOwner = OutcomeOwner Text
  deriving (Eq, Show)

data TaskItem = TaskItem
  { taskId :: Int
  , title :: Text
  , description :: Text
  , status :: Status
  , urgency :: Urgency
  , importance :: Importance
  , taskOwner :: TaskOwner
  , reviewOwner :: OutcomeOwner
  , expectedResult :: Text
  , submittedResult :: Maybe Text
  , reviewComment :: Maybe Text
  }
  deriving (Eq, Show)

data TaskInput = TaskInput
  { inputTitle :: Text
  , inputDescription :: Text
  , inputStatus :: Status
  , inputUrgency :: Urgency
  , inputImportance :: Importance
  , inputTaskOwner :: TaskOwner
  , inputReviewOwner :: OutcomeOwner
  , inputExpectedResult :: Text
  }
  deriving (Eq, Show)

data Outcome = Outcome
  { outcomeId :: Int
  , outcomeDescription :: Text
  , outcomeOwner :: OutcomeOwner
  , sourceTaskIds :: [Int]
  , outcomeResults :: [Text]
  , outcomeStatus :: Status
  }
  deriving (Eq, Show)

data OutcomeInput = OutcomeInput
  { inputOutcomeDescription :: Text
  , inputOutcomeOwner :: OutcomeOwner
  , inputSourceTaskIds :: [Int]
  }
  deriving (Eq, Show)

data TaskError
  = EmptyTitle
  | EmptyExpectedResult
  | EmptySubmittedResult
  | EmptyOutcomeDescription
  | NoTasksSelected
  | NotTaskOwner
  | NotOutcomeOwner
  | ResultNotSubmitted
  | TaskNotReadyForReview
  | TaskNotApproved
  deriving (Eq, Show)

createTask :: Int -> TaskInput -> TaskItem
createTask identifier input =
  TaskItem
    identifier
    (inputTitle input)
    (inputDescription input)
    (inputStatus input)
    (inputUrgency input)
    (inputImportance input)
    (inputTaskOwner input)
    (inputReviewOwner input)
    (inputExpectedResult input)
    Nothing
    Nothing

updateTask :: TaskItem -> TaskInput -> TaskItem
updateTask old input =
  old
    { title = inputTitle input
    , description = inputDescription input
    , status = inputStatus input
    , urgency = inputUrgency input
    , importance = inputImportance input
    , taskOwner = inputTaskOwner input
    , reviewOwner = inputReviewOwner input
    , expectedResult = inputExpectedResult input
    }

submitTaskResult :: TaskOwner -> Text -> TaskItem -> Either TaskError TaskItem
submitTaskResult actor taskResult task
  | actor /= taskOwner task = Left NotTaskOwner
  | Text.null (Text.strip taskResult) = Left EmptySubmittedResult
  | otherwise =
      Right
        task
          { submittedResult = Just taskResult
          , reviewComment = Nothing
          , status = Submitted
          }

approveTaskResult :: OutcomeOwner -> Maybe Text -> TaskItem -> Either TaskError TaskItem
approveTaskResult actor comment task
  | actor /= reviewOwner task = Left NotOutcomeOwner
  | isNothing (submittedResult task) = Left ResultNotSubmitted
  | status task /= Submitted = Left TaskNotReadyForReview
  | otherwise = Right task {reviewComment = comment, status = Approved}

requestTaskRevision :: OutcomeOwner -> Text -> TaskItem -> Either TaskError TaskItem
requestTaskRevision actor comment task
  | actor /= reviewOwner task = Left NotOutcomeOwner
  | isNothing (submittedResult task) = Left ResultNotSubmitted
  | status task /= Submitted = Left TaskNotReadyForReview
  | otherwise = Right task {reviewComment = Just comment, status = Reviewed}

assembleOutcome :: Int -> OutcomeInput -> [TaskItem] -> Either TaskError Outcome
assembleOutcome identifier input tasks
  | Text.null (Text.strip (inputOutcomeDescription input)) = Left EmptyOutcomeDescription
  | null tasks = Left NoTasksSelected
  | any ((/= inputOutcomeOwner input) . reviewOwner) tasks = Left NotOutcomeOwner
  | any ((/= Approved) . status) tasks = Left TaskNotApproved
  | otherwise =
      Right
        Outcome
          { outcomeId = identifier
          , outcomeDescription = inputOutcomeDescription input
          , outcomeOwner = inputOutcomeOwner input
          , sourceTaskIds = map taskId tasks
          , outcomeResults = [taskResult | task <- tasks, Just taskResult <- [submittedResult task]]
          , outcomeStatus = Effective
          }

toQuadrant :: Urgency -> Importance -> Quadrant
toQuadrant Urgent Important = DoFirst
toQuadrant NotUrgent Important = Schedule
toQuadrant Urgent NotImportant = Delegate
toQuadrant NotUrgent NotImportant = Eliminate

quadrantOf :: TaskItem -> Quadrant
quadrantOf task = toQuadrant (urgency task) (importance task)

validateTaskInput :: TaskInput -> Either TaskError TaskInput
validateTaskInput input
  | Text.null (Text.strip (inputTitle input)) = Left EmptyTitle
  | Text.null (Text.strip (inputExpectedResult input)) = Left EmptyExpectedResult
  | otherwise = Right input
