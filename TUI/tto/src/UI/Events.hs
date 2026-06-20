{-# LANGUAGE FlexibleContexts #-}

-- | Event handling logic (Effectful via Tagless Final)
--
-- This module handles user input events and updates application state.
-- Database operations are performed through the Tagless Final effect system.
module UI.Events
    ( handleEvent
    , trim
    ) where

import qualified App

import           Brick                  (BrickEvent (VtyEvent), EventM, get,
                                         halt, modify, zoom)
import qualified Brick.Widgets.Edit     as E
import           Brick.Widgets.List     (handleListEvent, listElementsL,
                                         listInsert, listModify, listRemove,
                                         listSelected)

import qualified Config

import           Control.Exception      (SomeException, try)
import           Control.Monad          (when)
import           Control.Monad.IO.Class (liftIO)

import qualified DB

import           Data.Maybe             (fromMaybe)
import qualified Data.Vector            as Vec

import           Flow                   ((<|))

import qualified Graphics.Vty           as V

import           Lens.Micro             ((%~), (.~), (^.))

import qualified TodoService

import           UI.Types

-- | 에러 메시지 설정 헬퍼
setError :: String -> EventM Name AppState ()
setError msg = modify <| errorMessage .~ Just msg

-- | 에러 메시지 초기화 헬퍼
clearError :: EventM Name AppState ()
clearError = modify <| errorMessage .~ Nothing

-- | 이벤트 처리 (Effectful)
handleEvent :: BrickEvent Name e -> EventM Name AppState ()
handleEvent ev = do
    s <- get
    case s ^. mode of
        ViewMode   -> handleViewMode ev
        InputMode  -> handleInputMode ev
        EditMode _ -> handleEditMode ev

-- | ViewMode 이벤트 처리 (Effectful)
handleViewMode :: BrickEvent Name e -> EventM Name AppState ()
handleViewMode (VtyEvent (V.EvKey key mods)) = do
    clearError
    s <- get
    let kb = keyBindings s
    case Config.matchesKeyWithMods kb key mods of
        Just Config.QuitApp        -> halt
        Just Config.AddTodo        -> enterInputMode
        Just Config.ToggleComplete -> cycleStatusForward
        Just Config.DeleteTodo     -> deleteSelectedTodo
        Just Config.NavigateUp     -> zoom todoList <| handleListEvent (V.EvKey V.KUp [])
        Just Config.NavigateDown   -> zoom todoList <| handleListEvent (V.EvKey V.KDown [])
        Just Config.EditTodo       -> enterEditModeFromList
        _                          -> pure ()
handleViewMode _ = pure ()

-- | InputMode로 전환 (Effectful)
enterInputMode :: EventM Name AppState ()
enterInputMode = do
    modify <| mode .~ InputMode
    modify <| focusedField .~ FocusAction

-- | 상태를 순환 전환 (Tagless Final 사용)
cycleStatusForward :: EventM Name AppState ()
cycleStatusForward = do
    s <- get
    case listSelected (s ^. todoList) of
        Nothing -> pure ()
        Just idx -> do
            let todos = s ^. todoList . listElementsL
            case todos Vec.!? idx of
                Nothing   -> pure ()
                Just todo -> transitionStatus (s ^. appEnv) (todo ^. todoId) (todo ^. todoStatus)

-- | 상태 전환 처리 (Tagless Final 사용)
transitionStatus :: App.AppEnv -> DB.TodoId -> String -> EventM Name AppState ()
transitionStatus env tid currentStatus = do
    result <- safeIO <| App.runAppM env (TodoService.cycleStatusForward tid currentStatus)
    case result of
        Left err -> setError $ "상태 전환 실패: " <> show err
        Right () -> do
            rowsResult <- safeIO <| App.runAppM env TodoService.loadAllTodos
            case rowsResult of
                Left err -> setError $ "데이터 로드 실패: " <> show err
                Right updatedRows ->
                    case TodoService.findTodoById tid updatedRows of
                        Just row ->
                            modify <|
                                todoList %~ listModify
                                    (\t -> t
                                        { _todoStatus = DB.todoStatus row
                                        , _todoStatusChangedAt = DB.todoStatusChangedAt row
                                        })
                        Nothing -> pure ()

-- | Todo 삭제 (Tagless Final 사용)
deleteSelectedTodo :: EventM Name AppState ()
deleteSelectedTodo = do
    s <- get
    case listSelected (s ^. todoList) of
        Nothing -> pure ()
        Just idx -> do
            let todos = s ^. todoList . listElementsL
            case todos Vec.!? idx of
                Nothing   -> pure ()
                Just todo -> deleteTodoFromDB (s ^. appEnv) (todo ^. todoId) idx

-- | DB에서 Todo 삭제 (Tagless Final 사용)
deleteTodoFromDB :: App.AppEnv -> DB.TodoId -> Int -> EventM Name AppState ()
deleteTodoFromDB env tid idx = do
    result <- safeIO <| App.runAppM env (TodoService.deleteTodoById tid)
    case result of
        Left err -> setError $ "삭제 실패: " <> show err
        Right () -> modify <| todoList %~ listRemove idx

-- | 리스트에서 선택된 항목 편집 모드로 전환
enterEditModeFromList :: EventM Name AppState ()
enterEditModeFromList = do
    s <- get
    case listSelected (s ^. todoList) of
        Nothing -> pure ()
        Just idx -> do
            let todos = s ^. todoList . listElementsL
            case todos Vec.!? idx of
                Nothing   -> pure ()
                Just todo -> enterEditMode todo idx

-- | EditMode로 전환
enterEditMode :: Todo -> Int -> EventM Name AppState ()
enterEditMode todo idx =
    modify <|
        (mode .~ EditMode (todo ^. todoId))
        . (editingIndex .~ Just idx)
        . (focusedField .~ FocusAction)
        . (actionEditor .~ E.editor ActionField (Just 1) (todo ^. todoAction))
        . (subjectEditor .~ E.editor SubjectField (Just 1)
            (fromMaybe "" <| todo ^. todoSubject))
        . (indirectObjectEditor .~ E.editor IndirectObjectField (Just 1)
            (fromMaybe "" <| todo ^. todoIndirectObject))
        . (directObjectEditor .~ E.editor DirectObjectField (Just 1)
            (fromMaybe "" <| todo ^. todoDirectObject))

-- | InputMode 이벤트 처리
handleInputMode :: BrickEvent Name e -> EventM Name AppState ()
handleInputMode (VtyEvent (V.EvKey key mods)) = do
    s <- get
    let kb = keyBindings s
    case Config.matchesKeyWithMods kb key mods of
        Just Config.CancelInput -> clearEditorsAndReturnToView
        Just Config.SaveInput   -> saveNewTodo
        _                       -> handleInputModeKey key mods
handleInputMode ev@(VtyEvent _) = handleEditorEvent ev
handleInputMode _ = return ()

-- | 새 Todo 저장 (Tagless Final 사용)
saveNewTodo :: EventM Name AppState ()
saveNewTodo = do
    s <- get
    let action = trim <| unlines <| E.getEditContents (s ^. actionEditor)
        subject = trim <| unlines <| E.getEditContents (s ^. subjectEditor)
        indirectObj = trim <| unlines <| E.getEditContents (s ^. indirectObjectEditor)
        directObj = trim <| unlines <| E.getEditContents (s ^. directObjectEditor)
        toMaybe txt = if null txt then Nothing else Just txt

    if not (null action)
        then createAndInsertTodo (s ^. appEnv) action
                (toMaybe subject) (toMaybe indirectObj) (toMaybe directObj)
        else modify <| mode .~ ViewMode

-- | Todo 생성 및 삽입 (Tagless Final 사용)
createAndInsertTodo :: App.AppEnv -> String -> Maybe String
                    -> Maybe String -> Maybe String -> EventM Name AppState ()
createAndInsertTodo env action subject indirectObj directObj = do
    result <- safeIO <| App.runAppM env <| do
        maybeTid <- TodoService.createNewTodo action subject indirectObj directObj
        case maybeTid of
            Nothing  -> pure Nothing
            Just tid -> do
                rows <- TodoService.loadAllTodos
                pure <| TodoService.findTodoById tid rows

    case result of
        Left err -> do
            setError $ "생성 실패: " <> show err
            modify <| mode .~ ViewMode
        Right newTodoRow ->
            case newTodoRow of
                Just row -> do
                    let newTodo = fromTodoRow row
                    modify <|
                        (todoList %~ listInsert 0 newTodo)
                        . (mode .~ ViewMode)
                    clearEditors
                Nothing -> modify <| mode .~ ViewMode

-- | InputMode 키 처리
handleInputModeKey :: V.Key -> [V.Modifier] -> EventM Name AppState ()
handleInputModeKey (V.KChar '\t') [] = cycleFieldFocus
handleInputModeKey key mods = do
    s <- get
    case s ^. focusedField of
        FocusAction         -> zoom actionEditor
            <| E.handleEditorEvent (VtyEvent (V.EvKey key mods))
        FocusSubject        -> zoom subjectEditor
            <| E.handleEditorEvent (VtyEvent (V.EvKey key mods))
        FocusIndirectObject -> zoom indirectObjectEditor
            <| E.handleEditorEvent (VtyEvent (V.EvKey key mods))
        FocusDirectObject   -> zoom directObjectEditor
            <| E.handleEditorEvent (VtyEvent (V.EvKey key mods))

-- | EditMode 이벤트 처리
handleEditMode :: BrickEvent Name e -> EventM Name AppState ()
handleEditMode (VtyEvent (V.EvKey key mods)) = do
    s <- get
    let kb = keyBindings s
    case Config.matchesKeyWithMods kb key mods of
        Just Config.CancelInput -> cancelEdit
        Just Config.SaveInput   -> saveEditedTodo
        _                       -> handleEditModeKey key mods
handleEditMode ev@(VtyEvent _) = handleEditorEvent ev
handleEditMode _ = return ()

-- | 편집 취소
cancelEdit :: EventM Name AppState ()
cancelEdit = do
    modify <| (mode .~ ViewMode) . (editingIndex .~ Nothing)
    clearEditors

-- | 편집된 Todo 저장 (Tagless Final 사용)
saveEditedTodo :: EventM Name AppState ()
saveEditedTodo = do
    s <- get
    let action = trim <| unlines <| E.getEditContents (s ^. actionEditor)
        subject = trim <| unlines <| E.getEditContents (s ^. subjectEditor)
        indirectObj = trim <| unlines <| E.getEditContents (s ^. indirectObjectEditor)
        directObj = trim <| unlines <| E.getEditContents (s ^. directObjectEditor)
        toMaybe txt = if null txt then Nothing else Just txt

    case s ^. mode of
        EditMode tid -> do
            when (not <| null action) <|
                updateTodoInDB (s ^. appEnv) tid action
                    (toMaybe subject) (toMaybe indirectObj) (toMaybe directObj)
            modify <| (mode .~ ViewMode) . (editingIndex .~ Nothing)
            clearEditors
        _ -> pure ()

-- | DB에서 Todo 업데이트 (Tagless Final 사용)
updateTodoInDB :: App.AppEnv -> DB.TodoId -> String
               -> Maybe String -> Maybe String -> Maybe String
               -> EventM Name AppState ()
updateTodoInDB env tid action subject indirectObj directObj = do
    s <- get
    case s ^. editingIndex of
        Nothing -> pure ()
        Just idx -> do
            let todos = s ^. todoList . listElementsL
            case todos Vec.!? idx of
                Nothing      -> pure ()
                Just oldTodo -> do
                    result <- safeIO <| App.runAppM env <|
                        TodoService.updateTodoById tid action
                            subject indirectObj directObj
                    case result of
                        Left err -> setError $ "업데이트 실패: " <> show err
                        Right () -> do
                            let updatedTodo = oldTodo
                                    { _todoAction = action
                                    , _todoSubject = subject
                                    , _todoIndirectObject = indirectObj
                                    , _todoDirectObject = directObj
                                    }
                            modify <| todoList %~ listModify (const updatedTodo)

-- | EditMode 키 처리
handleEditModeKey :: V.Key -> [V.Modifier] -> EventM Name AppState ()
handleEditModeKey (V.KChar '\t') [] = cycleFieldFocus
handleEditModeKey key mods = do
    s <- get
    case s ^. focusedField of
        FocusAction         -> zoom actionEditor
            <| E.handleEditorEvent (VtyEvent (V.EvKey key mods))
        FocusSubject        -> zoom subjectEditor
            <| E.handleEditorEvent (VtyEvent (V.EvKey key mods))
        FocusIndirectObject -> zoom indirectObjectEditor
            <| E.handleEditorEvent (VtyEvent (V.EvKey key mods))
        FocusDirectObject   -> zoom directObjectEditor
            <| E.handleEditorEvent (VtyEvent (V.EvKey key mods))

-- | 필드 포커스 순환
cycleFieldFocus :: EventM Name AppState ()
cycleFieldFocus = do
    s <- get
    let nextField = case s ^. focusedField of
            FocusAction         -> FocusSubject
            FocusSubject        -> FocusIndirectObject
            FocusIndirectObject -> FocusDirectObject
            FocusDirectObject   -> FocusAction
    modify <| focusedField .~ nextField

-- | 에디터 이벤트 처리
handleEditorEvent :: BrickEvent Name e -> EventM Name AppState ()
handleEditorEvent ev = do
    s <- get
    case s ^. focusedField of
        FocusAction         -> zoom actionEditor <| E.handleEditorEvent ev
        FocusSubject        -> zoom subjectEditor <| E.handleEditorEvent ev
        FocusIndirectObject -> zoom indirectObjectEditor <| E.handleEditorEvent ev
        FocusDirectObject   -> zoom directObjectEditor <| E.handleEditorEvent ev

-- | Utility: 문자열 trim (Pure)
trim :: String -> String
trim = unwords . words

-- | 에디터 초기화
clearEditors :: EventM Name AppState ()
clearEditors =
    modify <|
        (actionEditor .~ E.editor ActionField (Just 1) "")
        . (subjectEditor .~ E.editor SubjectField (Just 1) "")
        . (indirectObjectEditor .~ E.editor IndirectObjectField (Just 1) "")
        . (directObjectEditor .~ E.editor DirectObjectField (Just 1) "")

-- | 에디터 초기화 및 ViewMode로 복귀
clearEditorsAndReturnToView :: EventM Name AppState ()
clearEditorsAndReturnToView = do
    modify <| mode .~ ViewMode
    clearEditors

-- | IO 작업을 안전하게 실행하여 예외를 Either로 반환 (Effectful)
safeIO :: IO a -> EventM Name AppState (Either SomeException a)
safeIO = liftIO . try
