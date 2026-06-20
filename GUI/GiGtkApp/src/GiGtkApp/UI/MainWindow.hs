{-# LANGUAGE OverloadedLabels  #-}
{-# LANGUAGE OverloadedStrings #-}

module GiGtkApp.UI.MainWindow
  ( buildMainWindow
  ) where

import Control.Monad (forM_, unless)
import Data.GI.Base
import Data.GI.Base.Overloading (IsDescendantOf)
import Data.Int (Int32)
import Data.IORef (IORef, modifyIORef', newIORef, readIORef, writeIORef)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time (UTCTime, defaultTimeLocale, formatTime, getCurrentTime)
import GI.Gtk qualified as Gtk

import GiGtkApp.Config
import GiGtkApp.Domain.Todo

buildMainWindow :: Gtk.Application -> AppConfig -> IO ()
buildMainWindow app config = do
  todosRef <- newIORef []
  nextIdRef <- newIORef 1
  filterRef <- newIORef AllTodos

  window <-
    new
      Gtk.ApplicationWindow
      [ #application := app
      , #title := appWindowTitle config
      , #defaultWidth := appWindowWidth config
      , #defaultHeight := appWindowHeight config
      ]

  root <-
    new
      Gtk.Box
      [ #orientation := Gtk.OrientationVertical
      , #spacing := 12
      , #marginTop := 16
      , #marginBottom := 16
      , #marginStart := 16
      , #marginEnd := 16
      ]

  title <-
    new
      Gtk.Label
      [ #label := ("Todo" :: Text)
      , #xalign := 0
      ]

  inputBox <-
    new
      Gtk.Box
      [ #orientation := Gtk.OrientationHorizontal
      , #spacing := 8
      ]

  input <-
    new
      Gtk.Entry
      [ #placeholderText := ("할 일을 입력하세요" :: Text)
      , #hexpand := True
      ]
  resetEntryCursor input

  addButton <-
    new
      Gtk.Button
      [ #label := ("추가" :: Text)
      ]

  listBox <- new Gtk.ListBox []
  scrolled <-
    new
      Gtk.ScrolledWindow
      [ #vexpand := True
      , #hexpand := True
      ]

  filterBox <- buildFilterBox filterRef listBox todosRef

  appendToBox inputBox input
  appendToBox inputBox addButton

  appendToBox root title
  appendToBox root inputBox
  appendToBox root filterBox

  #setChild scrolled . Just =<< Gtk.toWidget listBox
  appendToBox root scrolled

  _ <-
    on addButton #clicked $
      addTodoFromInput todosRef nextIdRef filterRef listBox input

  #setChild window . Just =<< Gtk.toWidget root
  renderTodos todosRef filterRef listBox
  #show window

buildFilterBox
  :: IORef TodoFilter
  -> Gtk.ListBox
  -> IORef [TodoItem]
  -> IO Gtk.Box
buildFilterBox filterRef listBox todosRef = do
  filterBox <-
    new
      Gtk.Box
      [ #orientation := Gtk.OrientationHorizontal
      , #spacing := 8
      ]

  label <-
    new
      Gtk.Label
      [ #label := ("필터" :: Text)
      ]

  allButton <- filterButton "전체" AllTodos
  pendingButton <- filterButton "대기만" OnlyPending
  progressButton <- filterButton "진행만" OnlyInProgress
  doneButton <- filterButton "완료만" OnlyDone

  appendToBox filterBox label
  appendToBox filterBox allButton
  appendToBox filterBox pendingButton
  appendToBox filterBox progressButton
  appendToBox filterBox doneButton

  return filterBox
  where
    filterButton label targetFilter = do
      button <-
        new
          Gtk.Button
          [ #label := (label :: Text)
          ]
      _ <- on button #clicked $ do
        writeIORef filterRef targetFilter
        renderTodos todosRef filterRef listBox
      return button

addTodoFromInput
  :: IORef [TodoItem]
  -> IORef Int
  -> IORef TodoFilter
  -> Gtk.ListBox
  -> Gtk.Entry
  -> IO ()
addTodoFromInput todosRef nextIdRef filterRef listBox input = do
  rawTitle <- #getText input
  let title = Text.strip rawTitle
  unless (Text.null title) $ do
    newId <- readIORef nextIdRef
    now <- getCurrentTime
    modifyIORef' todosRef (addTodo newId title now)
    writeIORef nextIdRef (newId + 1)
    #setText input ("" :: Text)
    resetEntryCursor input
    renderTodos todosRef filterRef listBox

renderTodos :: IORef [TodoItem] -> IORef TodoFilter -> Gtk.ListBox -> IO ()
renderTodos todosRef filterRef listBox = do
  clearListBox listBox
  todos <- readIORef todosRef
  currentFilter <- readIORef filterRef
  let visibleTodos = filterTodos currentFilter todos
  if null visibleTodos
    then renderEmptyRow listBox
    else
      forM_ visibleTodos $
        renderTodoRow todosRef filterRef listBox

renderEmptyRow :: Gtk.ListBox -> IO ()
renderEmptyRow listBox = do
  row <- new Gtk.ListBoxRow []
  label <-
    new
      Gtk.Label
      [ #label := ("표시할 할 일이 없습니다." :: Text)
      , #xalign := 0
      , #marginTop := 10
      , #marginBottom := 10
      , #marginStart := 10
      , #marginEnd := 10
      ]
  #setChild row . Just =<< Gtk.toWidget label
  appendToListBox listBox row

renderTodoRow
  :: IORef [TodoItem]
  -> IORef TodoFilter
  -> Gtk.ListBox
  -> TodoItem
  -> IO ()
renderTodoRow todosRef filterRef listBox todo = do
  row <- new Gtk.ListBoxRow []
  rowBox <-
    new
      Gtk.Box
      [ #orientation := Gtk.OrientationVertical
      , #spacing := 8
      , #marginTop := 10
      , #marginBottom := 10
      , #marginStart := 10
      , #marginEnd := 10
      ]

  editBox <-
    new
      Gtk.Box
      [ #orientation := Gtk.OrientationHorizontal
      , #spacing := 8
      ]

  titleEntry <-
    new
      Gtk.Entry
      [ #hexpand := True
      ]
  #setText titleEntry (todoTitle todo)
  resetEntryCursor titleEntry

  status <-
    new
      Gtk.Label
      [ #label := ("상태: " <> statusLabel (todoStatus todo))
      ]

  saveButton <-
    new
      Gtk.Button
      [ #label := ("수정" :: Text)
      ]

  deleteButton <-
    new
      Gtk.Button
      [ #label := ("삭제" :: Text)
      ]

  statusBox <-
    new
      Gtk.Box
      [ #orientation := Gtk.OrientationHorizontal
      , #spacing := 8
      ]

  pendingButton <- statusButton "대기" Pending
  progressButton <- statusButton "진행" InProgress
  doneButton <- statusButton "완료" Done

  metadata <-
    new
      Gtk.Label
      [ #label := metadataLabel todo
      , #xalign := 0
      ]

  appendToBox editBox titleEntry
  appendToBox editBox status
  appendToBox editBox saveButton
  appendToBox editBox deleteButton

  appendToBox statusBox pendingButton
  appendToBox statusBox progressButton
  appendToBox statusBox doneButton

  appendToBox rowBox editBox
  appendToBox rowBox statusBox
  appendToBox rowBox metadata

  #setChild row . Just =<< Gtk.toWidget rowBox
  appendToListBox listBox row

  _ <- on saveButton #clicked $ do
    newTitle <- #getText titleEntry
    unless (Text.null (Text.strip newTitle)) $ do
      modifyIORef' todosRef (updateTodoTitle (todoId todo) newTitle)
      renderTodos todosRef filterRef listBox

  _ <- on deleteButton #clicked $ do
    modifyIORef' todosRef (deleteTodo (todoId todo))
    renderTodos todosRef filterRef listBox

  return ()
  where
    statusButton label targetStatus = do
      button <-
        new
          Gtk.Button
          [ #label := (label :: Text)
          ]
      _ <- on button #clicked $ do
        now <- getCurrentTime
        modifyIORef'
          todosRef
          (updateTodoStatus (todoId todo) targetStatus now)
        renderTodos todosRef filterRef listBox
      return button

clearListBox :: Gtk.ListBox -> IO ()
clearListBox listBox = do
  child <- #getFirstChild listBox
  case child of
    Nothing -> return ()
    Just widget -> do
      #remove listBox widget
      clearListBox listBox

appendToBox
  :: (GObject child, IsDescendantOf Gtk.Widget child) => Gtk.Box -> child -> IO ()
appendToBox parent child = do
  widget <- Gtk.toWidget child
  #append parent widget

appendToListBox
  :: (GObject child, IsDescendantOf Gtk.Widget child) => Gtk.ListBox -> child -> IO ()
appendToListBox parent child = do
  widget <- Gtk.toWidget child
  #append parent widget

resetEntryCursor :: Gtk.Entry -> IO ()
resetEntryCursor entry =
  #setPosition entry (0 :: Int32)

metadataLabel :: TodoItem -> Text
metadataLabel todo =
  "입력: "
    <> formatUtc (todoCreatedAt todo)
    <> " / 상태 변경: "
    <> formatUtc (todoStatusChangedAt todo)

formatUtc :: UTCTime -> Text
formatUtc =
  Text.pack . formatTime defaultTimeLocale "%Y-%m-%d %H:%M:%S UTC"
