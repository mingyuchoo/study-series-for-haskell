{-# LANGUAGE OverloadedStrings #-}

module Hfm.Application.UseCases (handleInput) where

import Control.Monad (when)
import Control.Monad.Except (ExceptT (..), runExceptT, throwError)
import Control.Monad.Reader (ReaderT, ask, runReaderT)
import Control.Monad.State.Strict (StateT, get, modify, runStateT)
import Control.Monad.Trans.Class (lift)
import qualified Data.ByteString as BS
import qualified Data.Text as T
import Data.Text.Encoding (decodeUtf8With)
import Data.Text.Encoding.Error (lenientDecode)
import Hfm.Application.Ports
import Hfm.Application.State
import Hfm.Domain.Editor (editText)
import Hfm.Domain.Entry
import Hfm.Domain.Input
import Hfm.Domain.Selection (selectAt, selectStep, selectedElement)
import System.FilePath (isAbsolute, normalise, takeDirectory, takeFileName, (</>))

type Action m = ExceptT () (StateT AppState (ReaderT (FileSystem m) m))

-- Run with Identity or a memory adapter in tests, and IO ports at the composition root.
handleInput :: Monad m => FileSystem m -> Input -> AppState -> m (AppState, Bool)
handleInput ports input state = do
  (outcome, updated) <- runReaderT (runStateT (runExceptT (dispatch input)) state) ports
  pure (updated, either (const True) (const False) outcome)

halt :: Monad m => Action m ()
halt = throwError ()

dispatch :: Monad m => Input -> Action m ()
dispatch (Resize w h) = modify (\s -> s { stTerminalSize = (w, h) })
dispatch (KeyPress (KFun 2) []) = modify toggleLanguage
dispatch (KeyPress (KFun 3) []) = modify toggleThemePicker
dispatch rawEvent = do
  st <- get
  let event = normalizeMeta rawEvent
  if stPendingCtrlX st
    then do
      modify (\s -> s { stPendingCtrlX = False })
      case event of
        KeyPress (KChar 'c') [MCtrl] -> halt
        KeyPress (KChar 'o') [] | stMode st == Browse && stThemePicker st == Nothing -> switchPanel
        KeyPress (KChar 'f') [MCtrl] | stMode st == Browse && stThemePicker st == Nothing -> enterSelected
        KeyPress (KChar 'k') [] -> cancelMode
        KeyPress (KChar 'g') [MCtrl] -> pure ()
        KeyPress KEsc [] -> pure ()
        _ -> modify (\s -> s { stStatus = "알 수 없는 C-x 명령" })
    else case event of
      KeyPress (KChar 'x') [MCtrl] -> modify (\s -> s { stPendingCtrlX = True })
      KeyPress (KChar 'g') [MCtrl] -> cancelMode
      _ -> case stThemePicker st of
        Just _ -> themePickerEvent event
        Nothing -> case stMode st of
          Browse -> browseEvent event
          Search -> searchEvent event
          Prompt op value -> promptEvent op value event
          ConfirmDelete -> confirmEvent event
          ViewFile path content offset -> viewEvent path content offset event


cancelMode :: Monad m => Action m ()
cancelMode = do
  st <- get
  case stThemePicker st of
    Just _ -> modify (\s -> s { stThemePicker = Nothing })
    Nothing -> do
      when (stMode st == Search || stMode st == Browse) (setSearch "")
      modify (\s -> s { stMode = Browse, stInputCursor = 0, stPendingCtrlX = False
                       , stStatus = "취소했습니다" })

themePickerEvent :: Monad m => Input -> Action m ()
themePickerEvent event = case event of
  KeyPress KEsc [] -> modify (\s -> s { stThemePicker = Nothing })
  KeyPress KEnter [] -> modify $ \s -> case stThemePicker s >>= selectedElement of
    Just (_, theme) -> s { stTheme = theme, stThemePicker = Nothing }
    Nothing -> s
  KeyPress KUp [] -> selectTheme (selectStep (-1))
  KeyPress KDown [] -> selectTheme (selectStep 1)
  KeyPress (KChar 'p') [MCtrl] -> selectTheme (selectStep (-1))
  KeyPress (KChar 'n') [MCtrl] -> selectTheme (selectStep 1)
  KeyPress KHome [] -> selectTheme (selectAt 0)
  KeyPress KEnd [] -> selectTheme (selectAt (-1))
  KeyPress (KChar '<') [MMeta] -> selectTheme (selectAt 0)
  KeyPress (KChar '>') [MMeta] -> selectTheme (selectAt (-1))
  KeyPress (KChar digit) [] | digit >= '1' && digit <= '6' -> selectTheme (selectAt (fromEnum digit - fromEnum '1'))
  _ -> pure ()
  where
    selectTheme change = modify (\s -> s { stThemePicker = change <$> stThemePicker s })

attempt :: Monad m => (FileSystem m -> m (Either FileError a)) -> (a -> Action m ()) -> Action m ()
attempt action onSuccess = do
  ports <- ask
  result <- lift (lift (lift (action ports)))
  case result of
    Left e -> modify (\s -> s { stStatus = "오류: " <> errorText e })
    Right value -> onSuccess value

refreshAll :: Monad m => Action m ()
refreshAll = do
  st <- get
  attempt (\ports -> runExceptT $ do
    left <- ExceptT (readEntries ports (stShowHidden st) (panelPath (stLeft st)))
    right <- ExceptT (readEntries ports (stShowHidden st) (panelPath (stRight st)))
    pure (left, right)) $ \(left, right) ->
      modify (\s -> s { stLeft = refreshPanel left Nothing (stLeft s)
                      , stRight = refreshPanel right Nothing (stRight s) })

changeDir :: Monad m => FilePath -> Maybe FilePath -> Action m ()
changeDir path preferred = do
  st <- get
  attempt (\ports -> runExceptT $ do
    canonical <- ExceptT (canonicalizePath ports path)
    entries <- ExceptT (readEntries ports (stShowHidden st) canonical)
    pure (canonical, entries)) $ \(canonical, entries) ->
      modify (\s ->
        let old = activePanel s
            panel = refreshPanel entries preferred (old { panelPath = canonical, panelSearch = "" })
        in (replaceActivePanel panel s) { stStatus = T.pack canonical })

enterSelected :: Monad m => Action m ()
enterSelected = do
  st <- get
  case selectedEntry st of
    Nothing -> pure ()
    Just entry -> case entryKind entry of
      Parent -> let current = panelPath (activePanel st)
                in changeDir (takeDirectory current) (Just (takeFileName current))
      Directory -> changeDir (panelPath (activePanel st) </> entryName entry) Nothing
      SymbolicLink -> do
        let path = panelPath (activePanel st) </> entryName entry
        attempt (\ports -> doesDirectoryExist ports path) $ \isDir -> if isDir then changeDir path Nothing else openView path
      RegularFile -> openView (panelPath (activePanel st) </> entryName entry)
      Special -> modify (\s -> s { stStatus = "특수 파일은 열 수 없습니다" })

openView :: Monad m => FilePath -> Action m ()
openView path = attempt (\ports -> readPreview ports path) $ \bytes ->
  if BS.elem 0 bytes
    then modify (\s -> s { stStatus = "바이너리 파일은 미리 볼 수 없습니다" })
    else modify (\s -> s { stMode = ViewFile path (decodeUtf8With lenientDecode bytes) 0 })

browseEvent :: Monad m => Input -> Action m ()
browseEvent event = do
  st <- get
  case event of
    KeyPress KUp [] -> modify (moveSelection False)
    KeyPress KDown [] -> modify (moveSelection True)
    KeyPress (KChar 'p') [MCtrl] -> modify (moveSelection False)
    KeyPress (KChar 'n') [MCtrl] -> modify (moveSelection True)
    KeyPress KPageUp [] -> modify (movePage False)
    KeyPress KPageDown [] -> modify (movePage True)
    KeyPress (KChar 'v') [MCtrl] -> modify (movePage True)
    KeyPress (KChar 'v') [MMeta] -> modify (movePage False)
    KeyPress (KChar '<') [MMeta] -> modify (moveBoundary False)
    KeyPress (KChar '>') [MMeta] -> modify (moveBoundary True)
    KeyPress KHome [] -> modify (moveBoundary False)
    KeyPress KEnd [] -> modify (moveBoundary True)
    KeyPress KEnter [] -> enterSelected
    KeyPress (KChar 'f') [] -> enterSelected
    KeyPress (KChar 's') [MCtrl] -> startSearch
    KeyPress (KChar 'r') [MCtrl] -> startSearch
    KeyPress (KChar 'g') [] -> refreshAll
    KeyPress (KChar 'o') [MMeta] -> modify (\s -> s { stShowHidden = not (stShowHidden s) }) >> refreshAll
    KeyPress (KChar 'v') [] -> case selectedEntry st of
      Just e | entryKind e `elem` [RegularFile, SymbolicLink] -> maybe (pure ()) openView (selectedPath st)
      _ -> pure ()
    KeyPress (KChar 'C') [] -> startPrompt Copy
    KeyPress (KChar 'R') [] -> startPrompt Move
    KeyPress (KChar '+') [] -> modify (\s -> s { stMode = Prompt Mkdir "", stInputCursor = 0 })
    KeyPress (KChar 'D') [] -> when (selectedPath st /= Nothing) $ modify (\s -> s { stMode = ConfirmDelete })
    KeyPress (KChar '^') [] -> changeDir (takeDirectory (panelPath (activePanel st))) (Just (takeFileName (panelPath (activePanel st))))
    _ -> pure ()
  where
    startSearch = modify (\s -> s { stMode = Search, stInputCursor = T.length (panelSearch (activePanel s)) })

moveBoundary :: Bool -> AppState -> AppState
moveBoundary end st =
  let panel = activePanel st
  in replaceActivePanel (panel { panelEntries = selectAt (if end then -1 else 0) (panelEntries panel) }) st

switchPanel :: Monad m => Action m ()
switchPanel = modify (\s -> s { stActive = if stActive s == LeftSide then RightSide else LeftSide })

movePage :: Bool -> AppState -> AppState
movePage down st = iterate (moveSelection down) st !! max 1 (snd (stTerminalSize st) - 6)

startPrompt :: Monad m => Operation -> Action m ()
startPrompt op = do
  st <- get
  when (maybe False ((/= Special) . entryKind) (selectedEntry st) && selectedPath st /= Nothing) $ do
    let other = if stActive st == LeftSide then stRight st else stLeft st
    let value = T.pack (panelPath other)
    modify (\s -> s { stMode = Prompt op value, stInputCursor = T.length value })

setSearch :: Monad m => T.Text -> Action m ()
setSearch query = modify $ \s ->
  let panel = activePanel s
      updated = refreshPanel (panelAll panel) Nothing (panel { panelSearch = query })
  in replaceActivePanel updated s

searchEvent :: Monad m => Input -> Action m ()
searchEvent event = case event of
  KeyPress KEsc [] -> cancel
  KeyPress (KChar 'g') [MCtrl] -> cancel
  KeyPress KEnter [] -> modify (\s -> s { stMode = Browse })
  KeyPress KUp [] -> modify (moveSelection False)
  KeyPress KDown [] -> modify (moveSelection True)
  KeyPress (KChar 'v') [MCtrl] -> modify (movePage True)
  KeyPress (KChar 'v') [MMeta] -> modify (movePage False)
  KeyPress (KChar 'p') [MCtrl] -> modify (moveSelection False)
  KeyPress (KChar 'n') [MCtrl] -> modify (moveSelection True)
  KeyPress (KChar 's') [MCtrl] -> modify (moveSelection True)
  KeyPress (KChar 'r') [MCtrl] -> modify (moveSelection False)
  KeyPress KPageUp [] -> modify (movePage False)
  KeyPress KPageDown [] -> modify (movePage True)
  KeyPress (KChar '<') [MMeta] -> modify (moveBoundary False)
  KeyPress (KChar '>') [MMeta] -> modify (moveBoundary True)
  _ -> do
    st <- get
    case editText event (panelSearch (activePanel st)) (stInputCursor st) of
      Just (value, cursor) -> setSearch value >> modify (\s -> s { stInputCursor = cursor })
      Nothing -> pure ()
  where
    cancel = setSearch "" >> modify (\s -> s { stMode = Browse, stInputCursor = 0 })

promptEvent :: Monad m => Operation -> T.Text -> Input -> Action m ()
promptEvent op value event = case event of
  KeyPress KEsc [] -> modify (\s -> s { stMode = Browse })
  KeyPress (KChar 'g') [MCtrl] -> modify (\s -> s { stMode = Browse })
  KeyPress KEnter [] -> runOperation op value
  _ -> do
    st <- get
    case editText event value (stInputCursor st) of
      Just (newValue, cursor) -> modify (\s -> s { stMode = Prompt op newValue, stInputCursor = cursor })
      Nothing -> pure ()

runOperation :: Monad m => Operation -> T.Text -> Action m ()
runOperation op raw = do
  st <- get
  let input = T.unpack (T.strip raw)
      cwd = panelPath (activePanel st)
  if null input || input == "." || input == ".." || (op == Mkdir && (isAbsolute input || takeFileName input /= input))
    then modify (\s -> s { stStatus = "유효한 대상 경로를 입력하세요" })
    else case op of
      Mkdir -> attempt (\ports -> makeDirectory ports (normalise (cwd </> input))) $ \_ -> finish "디렉터리를 만들었습니다"
      Copy -> runTransfer copyEntry "복사했습니다" cwd input st
      Move -> runTransfer moveEntry "이동했습니다" cwd input st

runTransfer :: Monad m => (FileSystem m -> FilePath -> FilePath -> m (Either FileError ())) -> T.Text -> FilePath -> FilePath -> AppState -> Action m ()
runTransfer operation message cwd input st = case selectedPath st of
  Nothing -> pure ()
  Just source -> attempt (\ports -> runExceptT $ do
    target <- ExceptT (destinationFor ports cwd source input)
    ExceptT (operation ports source target)) $ \_ -> finish message

finish :: Monad m => T.Text -> Action m ()
finish message = do
  modify (\s -> s { stMode = Browse, stStatus = message })
  refreshAll

confirmEvent :: Monad m => Input -> Action m ()
confirmEvent event = case event of
  KeyPress (KChar 'y') [] -> do
    st <- get
    case selectedPath st of
      Nothing -> modify (\s -> s { stMode = Browse })
      Just path -> attempt (\ports -> deleteEntry ports path) $ \_ -> finish "삭제했습니다"
  KeyPress (KChar 'Y') [] -> confirmEvent (KeyPress (KChar 'y') [])
  KeyPress _ _ -> modify (\s -> s { stMode = Browse, stStatus = "삭제를 취소했습니다" })
  _ -> pure ()

viewEvent :: Monad m => FilePath -> T.Text -> Int -> Input -> Action m ()
viewEvent path content offset event = case event of
  KeyPress KEsc [] -> close
  KeyPress (KChar 'g') [MCtrl] -> close
  KeyPress (KChar 'q') [] -> close
  KeyPress KUp [] -> scroll (-1)
  KeyPress KDown [] -> scroll 1
  KeyPress KPageUp [] -> scrollPage (-1)
  KeyPress KPageDown [] -> scrollPage 1
  KeyPress (KChar 'p') [MCtrl] -> scroll (-1)
  KeyPress (KChar 'n') [MCtrl] -> scroll 1
  KeyPress (KChar 'v') [MCtrl] -> scrollPage 1
  KeyPress (KChar 'v') [MMeta] -> scrollPage (-1)
  KeyPress (KChar '<') [MMeta] -> scrollTo 0
  KeyPress (KChar '>') [MMeta] -> scrollTo (length (T.lines content))
  KeyPress KHome [] -> scrollTo 0
  KeyPress KEnd [] -> scrollTo (length (T.lines content))
  _ -> pure ()
  where
    close = modify (\s -> s { stMode = Browse })
    scrollTo target = modify (\s -> s { stMode = ViewFile path content (clampViewerOffset s content target) })
    scroll step = scrollTo (offset + step)
    scrollPage direction = do
      st <- get
      scroll (direction * max 1 (viewerContentHeight st))
