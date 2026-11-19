module Todo.Application.Types where

import Todo.Domain.Model (Todo (..), TodoFields, TodoId, ValidationError)
import TodoStatus (TodoStatusType)

data FocusedField = FocusAction | FocusSubject | FocusIndirectObject | FocusDirectObject
  deriving (Eq, Show)

data Form = Form
  { formAction :: !String
  , formSubject :: !String
  , formIndirectObject :: !String
  , formDirectObject :: !String
  , formFocus :: !FocusedField
  }
  deriving (Eq, Show)

data Recovery
  = RecoverLoading
  | RecoverCreating Form
  | RecoverEditing Todo Form
  | RecoverDeleting TodoId
  | RecoverAdvancing TodoId TodoStatusType TodoStatusType
  deriving (Eq, Show)

data Pending
  = FetchingTodos
  | InsertingTodo Form TodoFields
  | UpdatingTodo Todo Form TodoFields
  | RemovingTodo TodoId
  | AdvancingTodo TodoId TodoStatusType TodoStatusType
  deriving (Eq, Show)

data Phase
  = NotStarted
  | Browsing
  | Creating Form
  | Editing Todo Form
  | Awaiting Pending
  | Failed WorkflowError Recovery
  | Stopped
  deriving (Eq, Show)

data Workflow = Workflow
  { workflowTodos :: ![Todo]
  , selectedId :: !(Maybe TodoId)
  , phase :: !Phase
  }
  deriving (Eq, Show)

data WorkflowError
  = InvalidFields ValidationError
  | RepositoryFailure String
  | InvalidStoredStatus TodoId String
  | MissingTodo TodoId
  | StaleStatus TodoId
  | WriteNotApplied
  deriving (Eq, Show)

data Command
  = LoadTodos
  | InsertTodo TodoFields
  | UpdateFields TodoId TodoFields
  | RemoveTodo TodoId
  | SetStatus TodoId TodoStatusType TodoStatusType
  deriving (Eq, Show)

data Result
  = TodosLoaded [Todo]
  | TodoCreated Todo
  | TodoUpdated Todo
  | TodoDeleted TodoId
  | StatusChanged Todo
  deriving (Eq, Show)

data Event
  = Start
  | BeginCreate
  | BeginEdit
  | Submit
  | Cancel
  | Retry
  | DismissError
  | DeleteSelected
  | CycleSelected
  | MoveUp
  | MoveDown
  | FocusNext
  | ChangeField FocusedField String
  | Quit
  | Succeeded Result
  | Rejected WorkflowError
  deriving (Eq, Show)
