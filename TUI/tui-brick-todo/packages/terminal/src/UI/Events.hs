module UI.Events
  ( handleEvent
  , dispatch
  , keyEvent
  , trim
  ) where

import Brick (BrickEvent (VtyEvent), EventM, get, halt, modify, zoom)
import Brick.Widgets.Edit qualified as E
import Config qualified
import Control.Monad (forM_, when)
import Control.Monad.IO.Class (liftIO)
import Data.List (intercalate)
import Data.Maybe (isJust)
import Graphics.Vty qualified as V
import Lens.Micro ((^.))
import Todo.Application.Repository (Repository, runCommand)
import Todo.Application.Workflow qualified as Workflow
import Todo.Domain.Model (normalize)
import UI.Types

handleEvent :: Repository IO -> BrickEvent Name e -> EventM Name AppState ()
handleEvent repository (VtyEvent event@(V.EvKey key modifiers)) = do
  state <- get
  case keyEvent state key modifiers of
    Just command -> dispatch repository command
    Nothing -> case Workflow.currentForm $ Workflow.phase $ state ^. workflow of
      Just _ -> editField repository $ VtyEvent event
      Nothing -> pure ()
handleEvent repository event@(VtyEvent _) = do
  state <- get
  case Workflow.currentForm $ Workflow.phase $ state ^. workflow of
    Just _ -> editField repository event
    Nothing -> pure ()
handleEvent _ _ = pure ()

keyEvent :: AppState -> V.Key -> [V.Modifier] -> Maybe Workflow.Event
keyEvent state key modifiers =
  let hasForm = case Workflow.currentForm $ Workflow.phase $ state ^. workflow of
        Just _ -> True
        Nothing -> False
      allowed =
        if hasForm
          then [Config.CancelInput, Config.SaveInput]
          else
            [ Config.QuitApp
            , Config.AddTodo
            , Config.EditTodo
            , Config.ToggleComplete
            , Config.DeleteTodo
            , Config.NavigateUp
            , Config.NavigateDown
            , Config.SaveInput
            , Config.CancelInput
            ]
      failed = isJust $ Workflow.workflowError (state ^. workflow)
   in case Config.matchesKeyFor allowed (keyBindings state) key modifiers of
        Just Config.QuitApp -> Just Workflow.Quit
        Just Config.AddTodo -> Just Workflow.BeginCreate
        Just Config.EditTodo -> Just Workflow.BeginEdit
        Just Config.ToggleComplete -> Just Workflow.CycleSelected
        Just Config.DeleteTodo -> Just Workflow.DeleteSelected
        Just Config.NavigateUp -> Just Workflow.MoveUp
        Just Config.NavigateDown -> Just Workflow.MoveDown
        Just Config.SaveInput | hasForm -> Just Workflow.Submit
        Just Config.SaveInput | failed -> Just Workflow.Retry
        Just Config.CancelInput -> Just Workflow.Cancel
        _ | hasForm && key == V.KChar '\t' && null modifiers -> Just Workflow.FocusNext
        _ -> Nothing

dispatch :: Repository IO -> Workflow.Event -> EventM Name AppState ()
dispatch repository event = do
  state <- get
  let (next, commands) = Workflow.transition event $ state ^. workflow
  modify $ projectWorkflow next
  when (Workflow.phase next == Workflow.Stopped) halt
  forM_ commands $ \command -> do
    result <- liftIO $ runCommand repository command
    dispatch repository result

editField :: Repository IO -> BrickEvent Name e -> EventM Name AppState ()
editField repository event = do
  before <- get
  let field = activeField before
  case field of
    FocusAction -> zoom actionEditor $ E.handleEditorEvent event
    FocusSubject -> zoom subjectEditor $ E.handleEditorEvent event
    FocusIndirectObject -> zoom indirectObjectEditor $ E.handleEditorEvent event
    FocusDirectObject -> zoom directObjectEditor $ E.handleEditorEvent event
  state <- get
  let editor = case field of
        FocusAction -> state ^. actionEditor
        FocusSubject -> state ^. subjectEditor
        FocusIndirectObject -> state ^. indirectObjectEditor
        FocusDirectObject -> state ^. directObjectEditor
  dispatch repository
    $ Workflow.ChangeField field
    $ intercalate "\n"
    $ E.getEditContents editor

trim :: String -> String
trim = normalize
