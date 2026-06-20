{-# LANGUAGE BinaryLiterals      #-}
{-# LANGUAGE FlexibleContexts    #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Main
  where

import Control.Lens
import Control.Monad (filterM, when)
import Control.Monad.IO.Class

import Data.Default
import Data.Maybe (fromMaybe, listToMaybe)
import Data.Text (Text)
import Data.Text qualified as T

import Monomer
import Monomer.Lens qualified as L

import System.Directory
  ( createDirectoryIfMissing
  , doesDirectoryExist
  , getAppUserDataDirectory
  , getCurrentDirectory
  )
import System.Environment (getExecutablePath)
import System.FilePath (takeDirectory, (</>))
import System.IO (BufferMode (NoBuffering), hSetBuffering, stdout)

import TextShow

import TodoLogic

import TodoRepo

import TodoRepoSqlite

import TodoTypes

-- | Todo 위젯 환경 타입
type TodoWenv = WidgetEnv TodoModel TodoEvt

-- | Todo 위젯 노드 타입
type TodoNode = WidgetNode TodoModel TodoEvt

-- UI 빌드 (화면 구성)
buildUI :: TodoWenv -> TodoModel -> TodoNode
buildUI wenv model = widgetTree
  where
    sectionBg = wenv ^. L.theme . L.sectionColor
    isEditing = case model ^. action of
      TodoAdding    -> True
      TodoEditing _ -> True
      _             -> False

    countLabel = label caption `styleBasic` styles
      where
        caption = "Tasks (" <> showt (length $ model ^. todos) <> ")"
        styles = [textFont "Regular", textSize 16, padding 20, bgColor sectionBg]

    todoList = vstack (zipWith (todoRow wenv model) [0 ..] (model ^. todos))

    newButton = mainButton "New" TodoNew `nodeKey` "todoNew" `nodeVisible` not isEditing

    editLayer = content
      where
        dualSlide content = outer
          where
            inner = animSlideIn_ [slideTop, duration 200] content `nodeKey` "animEditIn"
            outer =
              animSlideOut_ [slideTop, duration 200, onFinished TodoHideEditDone] inner
                `nodeKey` "animEditOut"

        content =
          vstack [dualSlide (todoEdit wenv model), filler]
            `styleBasic` [bgColor (grayDark & L.a .~ 0.5)]

    confirmDeleteLayer = case model ^. action of
      TodoConfirmingDelete idx todo -> [popup]
        where
          popup = confirmMsg msg (TodoConfirmDelete idx todo) TodoCancelDelete
          msg = "Are you sure you want to delete '" <> (todo ^. description) <> "' ?"
      _ -> []

    mainLayer =
      vstack
        [ countLabel
        , scroll_ [] (todoList `styleBasic` [padding 20, paddingT 5])
        , filler
        , box_ [alignRight] newButton `styleBasic` [bgColor sectionBg, padding 20]
        ]

    widgetTree = zstack ([mainLayer, editLayer `nodeVisible` isEditing] <> confirmDeleteLayer)

-- 이벤트 핸들러 (로직 처리)
handleEvent
  :: SqliteEnv
  -> TodoWenv
  -> TodoNode
  -> TodoModel
  -> TodoEvt
  -> [EventResponse TodoModel TodoEvt TodoModel TodoEvt]
handleEvent env wenv node model evt =
  case evt of
    TodoInit -> [Producer (loadTodosProducer env), SetFocusOnKey "todoNew"]
    TodoNew ->
      [ Event TodoShowEdit
      , Model $ model & action .~ TodoAdding & activeTodo .~ def
      , SetFocusOnKey "todoDesc"
      ]
    TodoEdit idx td ->
      [ Event TodoShowEdit
      , Model $ model & action .~ TodoEditing idx & activeTodo .~ td
      , SetFocusOnKey "todoDesc"
      ]
    TodoAdd ->
      [Producer (addTodoProducer env wenv model), Event TodoHideEdit, SetFocusOnKey "todoNew"]
    TodoSave idx ->
      [Producer (updateTodoProducer env idx model), Event TodoHideEdit, SetFocusOnKey "todoNew"]
    TodoCancel -> [Event TodoHideEdit, Model $ model & activeTodo .~ def, SetFocusOnKey "todoNew"]
    TodoDeleteBegin idx todo -> [Model (model & action .~ TodoConfirmingDelete idx todo)]
    TodoConfirmDelete idx todo ->
      [Model (model & action .~ TodoNone), Message (WidgetKey (todoRowKey todo)) AnimationStart]
    TodoCancelDelete -> [Model (model & action .~ TodoNone)]
    TodoDelete idx todo -> [Producer (deleteTodoProducer env todo), SetFocusOnKey "todoNew"]
    TodosLoaded loadedTodos -> [Model $ model & todos .~ loadedTodos]
    TodoHideEditDone -> [Model $ model & action .~ TodoNone]
    TodoShowEdit -> [Message "animEditIn" AnimationStart, Message "animEditOut" AnimationStop]
    TodoHideEdit -> [Message "animEditIn" AnimationStop, Message "animEditOut" AnimationStart]

-- Producer 함수들 (비동기 IO 작업)

-- | 모든 할일을 로드하는 Producer
loadTodosProducer :: SqliteEnv -> (TodoEvt -> IO ()) -> IO ()
loadTodosProducer env sendMsg = do
  todos <- runAppM env loadAllTodos
  sendMsg (TodosLoaded todos)

-- | 새 할일을 추가하는 Producer
addTodoProducer :: SqliteEnv -> WidgetEnv s e -> TodoModel -> (TodoEvt -> IO ()) -> IO ()
addTodoProducer env wenv model sendMsg = do
  let newTodo = model ^. activeTodo & todoId .~ currentTimeMs wenv
  _ <- runAppM env (saveTodo newTodo)
  todos <- runAppM env loadAllTodos
  sendMsg (TodosLoaded todos)

-- | 할일을 수정하는 Producer
updateTodoProducer :: SqliteEnv -> Int -> TodoModel -> (TodoEvt -> IO ()) -> IO ()
updateTodoProducer env idx model sendMsg = do
  let updatedTodo = model ^. activeTodo
  runAppM env (updateExistingTodo (fromIntegral $ updatedTodo ^. todoId) updatedTodo)
  todos <- runAppM env loadAllTodos
  sendMsg (TodosLoaded todos)

-- | 할일을 삭제하는 Producer
deleteTodoProducer :: SqliteEnv -> Todo -> (TodoEvt -> IO ()) -> IO ()
deleteTodoProducer env todo sendMsg = do
  runAppM env (removeExistingTodo (fromIntegral $ todo ^. todoId))
  todos <- runAppM env loadAllTodos
  sendMsg (TodosLoaded todos)

-- 초기 데이터 (데이터베이스가 비어있을 때만 사용)

-- | 초기 샘플 할일 목록
initialTodos :: [Todo]
initialTodos = todos
  where
    items =
      [ Todo 1 Home Done "Tidy up the room"
      , Todo 2 Home Pending "Buy groceries"
      , Todo 3 Home Pending "Pay the bills"
      , Todo 4 Home Pending "Repair kitchen sink"
      , Todo 5 Work Done "Check the status of project A"
      , Todo 6 Work Pending "Finish project B"
      , Todo 7 Work Pending "Send email to clients"
      , Todo 8 Work Pending "Contact cloud services provider"
      ]
    todos = items

-- 메인 함수
main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  dbPath <- resolveDatabasePath
  assetsDir <- resolveAssetsDir

  -- SQLite 환경 설정
  withSqliteEnv dbPath $ \env -> do
    -- 데이터베이스 초기화
    runAppM env initializeDb

    -- 초기 데이터 로드 (없으면 샘플 데이터 추가)
    existingTodos <- runAppM env loadAllTodos
    when (null existingTodos) $ do
      mapM_ (\todo -> runAppM env (saveTodo todo)) initialTodos

    -- 앱 시작
    startApp
      (TodoModel [] def TodoNone)
      (handleEvent env)
      buildUI
      (config assetsDir)
  where
    config assetsDir =
      [ appWindowTitle "Todo list"
      , appWindowIcon (pathText $ assetsDir </> "images" </> "icon.png")
      , appTheme customDarkTheme
      , appFontDef "Regular" (pathText $ assetsDir </> "fonts" </> "Roboto-Regular.ttf")
      , appFontDef "Medium" (pathText $ assetsDir </> "fonts" </> "Roboto-Medium.ttf")
      , appFontDef "Bold" (pathText $ assetsDir </> "fonts" </> "Roboto-Bold.ttf")
      , appFontDef "Remix" (pathText $ assetsDir </> "fonts" </> "remixicon.ttf")
      , appInitEvent TodoInit
      ]

pathText :: FilePath -> Text
pathText = T.pack

resolveDatabasePath :: IO FilePath
resolveDatabasePath = do
  dataDir <- getAppUserDataDirectory "MonomerTodo"
  createDirectoryIfMissing True dataDir
  return (dataDir </> "todos.db")

resolveAssetsDir :: IO FilePath
resolveAssetsDir = do
  cwd <- getCurrentDirectory
  exeDir <- takeDirectory <$> getExecutablePath
  let candidates =
        [ cwd </> "assets"
        , exeDir </> "assets"
        , exeDir </> ".." </> "assets"
        ]
  existing <- filterM doesDirectoryExist candidates
  return . fromMaybe (cwd </> "assets") . listToMaybe $ existing

-- 스타일 상수

-- | 완료된 할일 배경색
doneBg = rgbHex "#CFF6E2"

-- | 완료된 할일 글자색
doneFg = rgbHex "#459562"

-- | 대기중인 할일 배경색
pendingBg = rgbHex "#F5F0CC"

-- | 대기중인 할일 글자색
pendingFg = rgbHex "#827330"

-- | 밝은 회색
grayLight = rgbHex "#9E9E9E"

-- | 어두운 회색
grayDark = rgbHex "#393939"

-- | 더 어두운 회색
grayDarker = rgbHex "#2E2E2E"

-- | 커스텀 라이트 테마
customLightTheme :: Theme
customLightTheme = lightTheme & L.userColorMap . at "rowButton" ?~ grayLight

-- | 커스텀 다크 테마
customDarkTheme :: Theme
customDarkTheme = darkTheme & L.userColorMap . at "rowButton" ?~ gray

-- | 리스트에서 특정 인덱스의 요소 제거
remove :: Int -> [a] -> [a]
remove idx ls = take idx ls <> drop (idx + 1) ls

-- | Todo 항목의 고유 키 생성
todoRowKey :: Todo -> Text
todoRowKey todo = "todoRow" <> showt (todo ^. todoId)

-- | 할일 항목 하나를 표시하는 위젯
todoRow :: TodoWenv -> TodoModel -> Int -> Todo -> TodoNode
todoRow wenv model idx t = animRow `nodeKey` todoKey
  where
    sectionBg = wenv ^. L.theme . L.sectionColor
    rowButtonColor = wenv ^. L.theme . L.userColorMap . at "rowButton" . non def
    rowSepColor = gray & L.a .~ 0.5
    todoKey = todoRowKey t
    todoDone = t ^. status == Done
    isLast = idx == length (model ^. todos) - 1

    (todoBg, todoFg)
      | todoDone = (doneBg, doneFg)
      | otherwise = (pendingBg, pendingFg)

    todoStatus =
      labelS (t ^. status)
        `styleBasic` [ textFont "Medium"
                     , textSize 12
                     , textAscender
                     , textColor todoFg
                     , padding 6
                     , paddingH 8
                     , radius 12
                     , bgColor todoBg
                     ]

    rowButton caption action =
      button caption action
        `styleBasic` [ textFont "Remix"
                     , textMiddle
                     , textColor rowButtonColor
                     , bgColor transparent
                     , border 0 transparent
                     ]
        `styleHover` [bgColor sectionBg]
        `styleFocus` [bgColor (sectionBg & L.a .~ 0.5)]
        `styleFocusHover` [bgColor sectionBg]

    todoInfo =
      hstack
        [ vstack
            [ labelS (t ^. todoType) `styleBasic` [textSize 12, textColor darkGray]
            , spacer_ [width 5]
            , label (t ^. description) `styleBasic` [textThroughline_ todoDone]
            ]
        , filler
        , box_ [alignRight] todoStatus `styleBasic` [width 80]
        , spacer
        , rowButton remixEdit2Line (TodoEdit idx t)
        , spacer
        , rowButton remixDeleteBinLine (TodoDeleteBegin idx t)
        ]
        `styleBasic` [paddingV 15, styleIf (not isLast) $ borderB 1 rowSepColor]

    animRow = animFadeOut_ [onFinished (TodoDelete idx t)] todoInfo

-- | 할일 편집 화면 위젯
todoEdit :: TodoWenv -> TodoModel -> TodoNode
todoEdit wenv model = editNode
  where
    sectionBg = wenv ^. L.theme . L.sectionColor
    isValidInput = model ^. activeTodo . description /= ""

    (saveAction, saveLabel) = case model ^. action of
      TodoEditing idx -> (TodoSave idx, "Save")
      _               -> (TodoAdd, "Add")

    saveTodoBtn = mainButton saveLabel saveAction

    editFields =
      keystroke [("Enter", saveAction) | isValidInput] $
        vstack
          [ hstack [label "Task:", spacer, textField (activeTodo . description) `nodeKey` "todoDesc"]
          , spacer
          , hgrid
              [ hstack
                  [ label "Type:"
                  , spacer
                  , textDropdownS (activeTodo . todoType) todoTypes `nodeKey` "todoType"
                  , spacer
                  ]
              , hstack [label "Status:", spacer, textDropdownS (activeTodo . status) todoStatuses]
              ]
          ]

    editNode =
      keystroke [("Esc", TodoCancel)] $
        vstack
          [ editFields
          , spacer
          , hstack
              [filler, saveTodoBtn `nodeEnabled` isValidInput, spacer, button "Cancel" TodoCancel]
          ]
          `styleBasic` [bgColor sectionBg, padding 20]
