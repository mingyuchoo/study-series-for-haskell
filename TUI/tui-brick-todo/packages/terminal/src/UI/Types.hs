{-# LANGUAGE TemplateHaskell #-}

module UI.Types
  ( AppState (..)
  , FocusedField (..)
  , Mode (..)
  , Name (..)
  , Todo (..)
  , configuredKeys
  , actionEditor
  , directObjectEditor
  , fromDomainTodo
  , i18nMessages
  , indirectObjectEditor
  , keyBindings
  , subjectEditor
  , todoAction
  , todoCreatedAt
  , todoDirectObject
  , todoId
  , todoIndirectObject
  , todoList
  , todoStatus
  , todoStatusChangedAt
  , todoSubject
  , workflow
  , appMode
  , activeField
  , appError
  , initialState
  , projectWorkflow
  ) where

import Brick.Widgets.Edit qualified as E
import Brick.Widgets.List (List, list, listReplace)
import Config qualified
import Data.List (findIndex, intercalate)
import Data.Maybe (fromMaybe)
import Data.Vector qualified as Vec
import I18n qualified
import Lens.Micro.TH (makeLenses)
import Todo.Application.Types (FocusedField (..))
import Todo.Application.Workflow qualified as Workflow
import Todo.Domain.Model (ValidationError (EmptyAction))
import Todo.Domain.Model qualified as Domain
import TodoStatus (renderStatus)

data Mode = ViewMode | InputMode | EditMode Domain.TodoId
  deriving (Eq, Show)

data Name = TodoList | ActionField | SubjectField | IndirectObjectField | DirectObjectField
  deriving (Eq, Ord, Show)

data Todo = Todo
  { _todoId :: !Domain.TodoId
  , _todoAction :: !String
  , _todoStatus :: !String
  , _todoCreatedAt :: !String
  , _todoSubject :: !(Maybe String)
  , _todoIndirectObject :: !(Maybe String)
  , _todoDirectObject :: !(Maybe String)
  , _todoStatusChangedAt :: !(Maybe String)
  }
  deriving (Eq, Show)

makeLenses ''Todo

data AppState = AppState
  { _todoList :: !(List Name Todo)
  , _actionEditor :: !(E.Editor String Name)
  , _subjectEditor :: !(E.Editor String Name)
  , _indirectObjectEditor :: !(E.Editor String Name)
  , _directObjectEditor :: !(E.Editor String Name)
  , _workflow :: !Workflow.Workflow
  , _configuredKeys :: !Config.KeyBindings
  , _i18nMessages :: !I18n.I18nMessages
  }

makeLenses ''AppState

keyBindings :: AppState -> Config.KeyBindings
keyBindings = _configuredKeys

appMode :: AppState -> Mode
appMode state = case Workflow.phase $ _workflow state of
  Workflow.Editing todo _ -> EditMode $ Domain.identifier todo
  Workflow.Awaiting (Workflow.UpdatingTodo todo _ _) -> EditMode $ Domain.identifier todo
  Workflow.Failed _ (Workflow.RecoverEditing todo _) -> EditMode $ Domain.identifier todo
  phase | Just _ <- Workflow.currentForm phase -> InputMode
  _ -> ViewMode

activeField :: AppState -> FocusedField
activeField =
  maybe FocusAction Workflow.formFocus . Workflow.currentForm . Workflow.phase . _workflow

appError :: AppState -> Maybe String
appError state = renderError <$> Workflow.workflowError (_workflow state)
  where
    renderError (Workflow.InvalidFields EmptyAction) = I18n.action_required_label $ I18n.fields $ _i18nMessages state
    renderError (Workflow.RepositoryFailure message) = message
    renderError (Workflow.InvalidStoredStatus target value) = "Invalid status for todo " <> show target <> ": " <> value
    renderError (Workflow.MissingTodo target) = I18n.not_found (I18n.ui $ _i18nMessages state) <> ": " <> show target
    renderError (Workflow.StaleStatus target) = "Status changed for todo " <> show target
    renderError Workflow.WriteNotApplied = "The database did not apply the requested change"

initialState :: Config.KeyBindings -> I18n.I18nMessages -> AppState
initialState keys messages =
  AppState
    { _todoList = list TodoList Vec.empty 1
    , _actionEditor = E.editor ActionField (Just 1) ""
    , _subjectEditor = E.editor SubjectField (Just 1) ""
    , _indirectObjectEditor = E.editor IndirectObjectField (Just 1) ""
    , _directObjectEditor = E.editor DirectObjectField (Just 1) ""
    , _workflow = Workflow.initialWorkflow
    , _configuredKeys = keys
    , _i18nMessages = messages
    }

projectWorkflow :: Workflow.Workflow -> AppState -> AppState
projectWorkflow next state =
  let form = fromMaybe Workflow.emptyForm $ Workflow.currentForm $ Workflow.phase next
      rows = Workflow.workflowTodos next
      selected =
        Workflow.selectedId next >>= \target -> findIndex ((== target) . Domain.identifier) rows
      old = _workflow state
      unchangedList =
        rows == Workflow.workflowTodos old && Workflow.selectedId next == Workflow.selectedId old
   in state
        { _workflow = next
        , _todoList =
            if unchangedList
              then _todoList state
              else listReplace (Vec.fromList $ map fromDomainTodo rows) selected $ _todoList state
        , _actionEditor =
            synchronizeEditor ActionField (Workflow.formAction form) $ _actionEditor state
        , _subjectEditor =
            synchronizeEditor SubjectField (Workflow.formSubject form) $ _subjectEditor state
        , _indirectObjectEditor =
            synchronizeEditor IndirectObjectField (Workflow.formIndirectObject form) $
              _indirectObjectEditor state
        , _directObjectEditor =
            synchronizeEditor DirectObjectField (Workflow.formDirectObject form) $
              _directObjectEditor state
        }

synchronizeEditor :: Name -> String -> E.Editor String Name -> E.Editor String Name
synchronizeEditor name value editor
  | intercalate "\n" (E.getEditContents editor) == value = editor
  | otherwise = E.editor name (Just 1) value

fromDomainTodo :: Domain.Todo -> Todo
fromDomainTodo todo =
  let value = Domain.fields todo
   in Todo
        (Domain.identifier todo)
        (Domain.action value)
        (renderStatus $ Domain.status todo)
        (Domain.createdAt todo)
        (Domain.subject value)
        (Domain.indirectObject value)
        (Domain.directObject value)
        (Domain.changedAt todo)
