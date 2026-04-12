{-# LANGUAGE TemplateHaskell #-}

-- | UI data types and lenses (Pure)
--
-- This module contains all data type definitions for the UI layer.
-- All functions are pure.
module UI.Types
    ( AppState (..)
    , FocusedField (..)
    , Mode (..)
    , Name (..)
    , Todo (..)
    , actionEditor
    , appEnv
    , directObjectEditor
    , editingIndex
    , errorMessage
    , focusedField
    , fromTodoRow
    , i18nMessages
    , indirectObjectEditor
    , keyBindings
    , mode
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
    ) where

import qualified App

import qualified Brick.Widgets.Edit as E
import           Brick.Widgets.List (List)

import qualified Config

import qualified DB

import qualified I18n

import           Lens.Micro.TH      (makeLenses)

-- | Application modes (Pure)
data Mode = ViewMode
          | InputMode
          | EditMode DB.TodoId
     deriving (Eq, Show)

-- | Widget resource names (Pure)
data Name = TodoList | ActionField | SubjectField | IndirectObjectField | DirectObjectField
     deriving (Eq, Ord, Show)

-- | Field focus tracking (Pure)
data FocusedField = FocusAction | FocusSubject | FocusIndirectObject | FocusDirectObject
     deriving (Eq, Show)

-- | UI representation of a Todo item (Pure)
data Todo = Todo { _todoId              :: !DB.TodoId
                 , _todoAction          :: !String
                 , _todoStatus          :: !String
                 , _todoCreatedAt       :: !String
                 , _todoSubject         :: !(Maybe String)
                 , _todoIndirectObject  :: !(Maybe String)
                 , _todoDirectObject    :: !(Maybe String)
                 , _todoStatusChangedAt :: !(Maybe String)
                 }
     deriving (Eq, Show)

makeLenses ''Todo

-- | Application state (Pure)
data AppState = AppState { _todoList             :: !(List Name Todo)
                         , _actionEditor         :: !(E.Editor String Name)
                         , _subjectEditor        :: !(E.Editor String Name)
                         , _indirectObjectEditor :: !(E.Editor String Name)
                         , _directObjectEditor   :: !(E.Editor String Name)
                         , _focusedField         :: !FocusedField
                         , _mode                 :: !Mode
                         , _appEnv               :: !App.AppEnv
                         , _editingIndex         :: !(Maybe Int)
                         , _i18nMessages         :: !I18n.I18nMessages
                         , _errorMessage         :: !(Maybe String)
                         }

makeLenses ''AppState

-- | Get key bindings from app state
keyBindings :: AppState -> Config.KeyBindings
keyBindings s = App.envKeyBindings (_appEnv s)

-- | Convert DB TodoRow to UI Todo (Pure)
fromTodoRow :: DB.TodoRow -> Todo
fromTodoRow row = Todo
    { _todoId = DB.todoId row
    , _todoAction = DB.todoAction row
    , _todoStatus = DB.todoStatus row
    , _todoCreatedAt = DB.todoCreatedAt row
    , _todoSubject = DB.todoSubject row
    , _todoIndirectObject = DB.todoIndirectObject row
    , _todoDirectObject = DB.todoDirectObject row
    , _todoStatusChangedAt = DB.todoStatusChangedAt row
    }
