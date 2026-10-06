{-# LANGUAGE OverloadedStrings #-}

module Event (handleEvent, formatFileError, editText) where

import Brick (BrickEvent (..), EventM, get, halt, modify)
import Config (KeyBindingStyle (..))
import Control.Exception (IOException, try)
import Control.Monad (when)
import Control.Monad.IO.Class (liftIO)
import Data.Char (isAlphaNum)
import qualified Data.ByteString as BS
import qualified Data.Text as T
import Data.Text.Encoding (decodeUtf8With)
import Data.Text.Encoding.Error (lenientDecode)
import FileManager
import qualified Graphics.Vty as V
import System.Directory (canonicalizePath, doesDirectoryExist)
import System.FilePath (isAbsolute, normalise, takeDirectory, takeFileName, (</>))
import System.IO (IOMode (ReadMode), withBinaryFile)
import System.IO.Error (isDoesNotExistError, isPermissionError)
import Types

formatFileError :: IOException -> T.Text
formatFileError e
  | isDoesNotExistError e = "파일이 존재하지 않습니다"
  | isPermissionError e = "파일 접근 권한이 없습니다"
  | otherwise = T.pack (show e)

handleEvent :: BrickEvent Name e -> EventM Name AppState ()
handleEvent (VtyEvent (V.EvResize w h)) = modify (\s -> s { stTerminalSize = (w, h) })
handleEvent (VtyEvent event) = do
  st <- get
  case stMode st of
    Browse -> browseEvent event
    Search -> searchEvent event
    Prompt op value -> promptEvent op value event
    ConfirmDelete -> confirmEvent event
    ViewFile path content offset -> viewEvent path content offset event
handleEvent _ = pure ()

attempt :: IO a -> (a -> EventM Name AppState ()) -> EventM Name AppState ()
attempt action onSuccess = do
  result <- liftIO (try action)
  case result of
    Left e -> modify (\s -> s { stStatus = "오류: " <> formatFileError e })
    Right value -> onSuccess value

refreshAll :: EventM Name AppState ()
refreshAll = do
  st <- get
  attempt (do
    left <- readEntries (stShowHidden st) (panelPath (stLeft st))
    right <- readEntries (stShowHidden st) (panelPath (stRight st))
    pure (left, right)) $ \(left, right) ->
      modify (\s -> s { stLeft = refreshPanel left Nothing (stLeft s)
                      , stRight = refreshPanel right Nothing (stRight s) })

changeDir :: FilePath -> Maybe FilePath -> EventM Name AppState ()
changeDir path preferred = do
  st <- get
  attempt (do
    canonical <- canonicalizePath path
    entries <- readEntries (stShowHidden st) canonical
    pure (canonical, entries)) $ \(canonical, entries) ->
      modify (\s ->
        let old = activePanel s
            panel = refreshPanel entries preferred (old { panelPath = canonical, panelSearch = "" })
        in (replaceActivePanel panel s) { stStatus = T.pack canonical })

enterSelected :: EventM Name AppState ()
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
        attempt (doesDirectoryExist path) $ \isDir -> if isDir then changeDir path Nothing else openView path
      RegularFile -> openView (panelPath (activePanel st) </> entryName entry)
      Special -> modify (\s -> s { stStatus = "특수 파일은 열 수 없습니다" })

openView :: FilePath -> EventM Name AppState ()
openView path = attempt (withBinaryFile path ReadMode (\h -> BS.hGet h 65536)) $ \bytes ->
  if BS.elem 0 bytes
    then modify (\s -> s { stStatus = "바이너리 파일은 미리 볼 수 없습니다" })
    else modify (\s -> s { stMode = ViewFile path (decodeUtf8With lenientDecode bytes) 0 })

browseEvent :: V.Event -> EventM Name AppState ()
browseEvent event = do
  st <- get
  if stPendingCtrlX st
    then do
      modify (\s -> s { stPendingCtrlX = False })
      case event of
        V.EvKey (V.KChar 'c') [V.MCtrl] -> halt
        V.EvKey (V.KChar 'o') [] -> switchPanel
        V.EvKey (V.KChar 'g') [V.MCtrl] -> pure ()
        V.EvKey V.KEsc [] -> pure ()
        _ -> modify (\s -> s { stStatus = "알 수 없는 C-x 명령" })
    else browseKey st event

browseKey :: AppState -> V.Event -> EventM Name AppState ()
browseKey st event = case event of
    V.EvKey (V.KChar 'x') [V.MCtrl] | configKeyBinding (stConfig st) == Emacs -> modify (\s -> s { stPendingCtrlX = True })
    V.EvKey (V.KChar 'q') [] -> halt
    V.EvKey (V.KChar '\t') [] -> switchPanel
    V.EvKey V.KUp [] -> modify (moveSelection False)
    V.EvKey V.KDown [] -> modify (moveSelection True)
    V.EvKey V.KPageUp [] -> modify (\s -> iterate (moveSelection False) s !! 10)
    V.EvKey V.KPageDown [] -> modify (\s -> iterate (moveSelection True) s !! 10)
    V.EvKey (V.KChar 'v') [V.MCtrl] | configKeyBinding (stConfig st) == Emacs -> modify (movePage True)
    V.EvKey (V.KChar 'v') [V.MMeta] | configKeyBinding (stConfig st) == Emacs -> modify (movePage False)
    V.EvKey V.KEnter [] -> enterSelected
    V.EvKey V.KBS [] -> changeDir (takeDirectory (panelPath (activePanel st))) (Just (takeFileName (panelPath (activePanel st))))
    V.EvKey (V.KChar '/') [] -> modify (\s -> s { stMode = Search, stInputCursor = T.length (panelSearch (activePanel s)) })
    V.EvKey (V.KChar 's') [V.MCtrl] | configKeyBinding (stConfig st) == Emacs -> modify (\s -> s { stMode = Search, stInputCursor = T.length (panelSearch (activePanel s)) })
    V.EvKey (V.KChar 'r') [V.MCtrl] -> refreshAll
    V.EvKey (V.KChar 'g') [] -> refreshAll
    V.EvKey (V.KChar '.') [] -> modify (\s -> s { stShowHidden = not (stShowHidden s) }) >> refreshAll
    V.EvKey (V.KChar 'v') [] -> case selectedEntry st of
      Just e | entryKind e `elem` [RegularFile, SymbolicLink] -> maybe (pure ()) openView (selectedPath st)
      _ -> pure ()
    V.EvKey (V.KChar 'C') [] -> startPrompt Copy
    V.EvKey (V.KChar 'R') [] -> startPrompt Move
    V.EvKey (V.KChar '+') [] -> modify (\s -> s { stMode = Prompt Mkdir "", stInputCursor = 0 })
    V.EvKey (V.KChar 'D') [] -> when (selectedPath st /= Nothing) $ modify (\s -> s { stMode = ConfirmDelete })
    V.EvKey (V.KChar '^') [] -> changeDir (takeDirectory (panelPath (activePanel st))) (Just (takeFileName (panelPath (activePanel st))))
    V.EvKey (V.KChar 'p') [V.MCtrl] | configKeyBinding (stConfig st) == Emacs -> modify (moveSelection False)
    V.EvKey (V.KChar 'n') [V.MCtrl] | configKeyBinding (stConfig st) == Emacs -> modify (moveSelection True)
    V.EvKey (V.KChar 'k') [] | configKeyBinding (stConfig st) == Vim -> modify (moveSelection False)
    V.EvKey (V.KChar 'j') [] | configKeyBinding (stConfig st) == Vim -> modify (moveSelection True)
    V.EvKey (V.KChar 'h') [] | configKeyBinding (stConfig st) == Vim -> changeDir (takeDirectory (panelPath (activePanel st))) (Just (takeFileName (panelPath (activePanel st))))
    V.EvKey (V.KChar 'l') [] | configKeyBinding (stConfig st) == Vim -> enterSelected
    _ -> pure ()

switchPanel :: EventM Name AppState ()
switchPanel = modify (\s -> s { stActive = if stActive s == LeftSide then RightSide else LeftSide })

movePage :: Bool -> AppState -> AppState
movePage down st = iterate (moveSelection down) st !! max 1 (snd (stTerminalSize st) - 6)

startPrompt :: Operation -> EventM Name AppState ()
startPrompt op = do
  st <- get
  when (maybe False ((/= Special) . entryKind) (selectedEntry st) && selectedPath st /= Nothing) $ do
    let other = if stActive st == LeftSide then stRight st else stLeft st
    let value = T.pack (panelPath other)
    modify (\s -> s { stMode = Prompt op value, stInputCursor = T.length value })

setSearch :: T.Text -> EventM Name AppState ()
setSearch query = modify $ \s ->
  let panel = activePanel s
      updated = refreshPanel (panelAll panel) Nothing (panel { panelSearch = query })
  in replaceActivePanel updated s

searchEvent :: V.Event -> EventM Name AppState ()
searchEvent event = case event of
  V.EvKey V.KEsc [] -> cancel
  V.EvKey (V.KChar 'g') [V.MCtrl] -> cancel
  V.EvKey V.KEnter [] -> modify (\s -> s { stMode = Browse })
  V.EvKey V.KUp [] -> modify (moveSelection False)
  V.EvKey V.KDown [] -> modify (moveSelection True)
  V.EvKey (V.KChar 'v') [V.MCtrl] -> modify (movePage True)
  V.EvKey (V.KChar 'v') [V.MMeta] -> modify (movePage False)
  V.EvKey (V.KChar 'p') [V.MCtrl] -> modify (moveSelection False)
  V.EvKey (V.KChar 'n') [V.MCtrl] -> modify (moveSelection True)
  _ -> do
    st <- get
    case editText event (panelSearch (activePanel st)) (stInputCursor st) of
      Just (value, cursor) -> setSearch value >> modify (\s -> s { stInputCursor = cursor })
      Nothing -> pure ()
  where
    cancel = setSearch "" >> modify (\s -> s { stMode = Browse, stInputCursor = 0 })

promptEvent :: Operation -> T.Text -> V.Event -> EventM Name AppState ()
promptEvent op value event = case event of
  V.EvKey V.KEsc [] -> modify (\s -> s { stMode = Browse })
  V.EvKey (V.KChar 'g') [V.MCtrl] -> modify (\s -> s { stMode = Browse })
  V.EvKey V.KEnter [] -> runOperation op value
  _ -> do
    st <- get
    case editText event value (stInputCursor st) of
      Just (newValue, cursor) -> modify (\s -> s { stMode = Prompt op newValue, stInputCursor = cursor })
      Nothing -> pure ()

-- | Edit a one-line input. Cursor positions count Text characters, not bytes.
editText :: V.Event -> T.Text -> Int -> Maybe (T.Text, Int)
editText event value rawCursor = case event of
  V.EvKey (V.KChar 'a') [V.MCtrl] -> Just (value, 0)
  V.EvKey (V.KChar 'e') [V.MCtrl] -> Just (value, T.length value)
  V.EvKey (V.KChar 'b') [V.MCtrl] -> Just (value, max 0 (cursor - 1))
  V.EvKey (V.KChar 'f') [V.MCtrl] -> Just (value, min (T.length value) (cursor + 1))
  V.EvKey V.KLeft [] -> Just (value, max 0 (cursor - 1))
  V.EvKey V.KRight [] -> Just (value, min (T.length value) (cursor + 1))
  V.EvKey (V.KChar 'u') [V.MCtrl] -> Just ("", 0)
  V.EvKey (V.KChar 'k') [V.MCtrl] -> Just (T.take cursor value, cursor)
  V.EvKey (V.KChar 'w') [V.MCtrl] -> Just (T.take wordStart value <> T.drop cursor value, wordStart)
  V.EvKey (V.KChar 'h') [V.MCtrl] -> deleteBackward
  V.EvKey V.KBS [] -> deleteBackward
  V.EvKey (V.KChar 'd') [V.MCtrl] -> deleteForward
  V.EvKey V.KDel [] -> deleteForward
  V.EvKey (V.KChar c) [] -> Just (T.take cursor value <> T.singleton c <> T.drop cursor value, cursor + 1)
  _ -> Nothing
  where
    cursor = max 0 (min (T.length value) rawCursor)
    deleteBackward
      | cursor == 0 = Just (value, cursor)
      | otherwise = Just (T.take (cursor - 1) value <> T.drop cursor value, cursor - 1)
    deleteForward
      | cursor == T.length value = Just (value, cursor)
      | otherwise = Just (T.take cursor value <> T.drop (cursor + 1) value, cursor)
    beforeCursor = T.take cursor value
    wordStart = T.length (T.dropWhileEnd isWordChar (T.dropWhileEnd (not . isWordChar) beforeCursor))
    isWordChar c = isAlphaNum c || c == '_'

runOperation :: Operation -> T.Text -> EventM Name AppState ()
runOperation op raw = do
  st <- get
  let input = T.unpack (T.strip raw)
      cwd = panelPath (activePanel st)
  if null input || input == "." || input == ".." || (op == Mkdir && (isAbsolute input || takeFileName input /= input))
    then modify (\s -> s { stStatus = "유효한 대상 경로를 입력하세요" })
    else case op of
      Mkdir -> attempt (makeDirectory (normalise (cwd </> input))) $ \_ -> finish "디렉터리를 만들었습니다"
      Copy -> runTransfer copyEntry "복사했습니다" cwd input st
      Move -> runTransfer moveEntry "이동했습니다" cwd input st

runTransfer :: (FilePath -> FilePath -> IO ()) -> T.Text -> FilePath -> FilePath -> AppState -> EventM Name AppState ()
runTransfer operation message cwd input st = case selectedPath st of
  Nothing -> pure ()
  Just source -> attempt (do
    target <- destinationFor cwd source input
    operation source target) $ \_ -> finish message

finish :: T.Text -> EventM Name AppState ()
finish message = do
  modify (\s -> s { stMode = Browse, stStatus = message })
  refreshAll

confirmEvent :: V.Event -> EventM Name AppState ()
confirmEvent event = case event of
  V.EvKey (V.KChar 'y') [] -> do
    st <- get
    case selectedPath st of
      Nothing -> modify (\s -> s { stMode = Browse })
      Just path -> attempt (deleteEntry path) $ \_ -> finish "삭제했습니다"
  V.EvKey (V.KChar 'Y') [] -> confirmEvent (V.EvKey (V.KChar 'y') [])
  V.EvKey _ _ -> modify (\s -> s { stMode = Browse, stStatus = "삭제를 취소했습니다" })
  _ -> pure ()

viewEvent :: FilePath -> T.Text -> Int -> V.Event -> EventM Name AppState ()
viewEvent path content offset event = case event of
  V.EvKey V.KEsc [] -> close
  V.EvKey (V.KChar 'g') [V.MCtrl] -> close
  V.EvKey (V.KChar 'q') [] -> close
  V.EvKey V.KUp [] -> scroll (-1)
  V.EvKey V.KDown [] -> scroll 1
  V.EvKey V.KPageUp [] -> scroll (-10)
  V.EvKey V.KPageDown [] -> scroll 10
  V.EvKey (V.KChar 'p') [V.MCtrl] -> scroll (-1)
  V.EvKey (V.KChar 'n') [V.MCtrl] -> scroll 1
  V.EvKey (V.KChar 'v') [V.MCtrl] -> scrollPage 1
  V.EvKey (V.KChar 'v') [V.MMeta] -> scrollPage (-1)
  _ -> pure ()
  where
    close = modify (\s -> s { stMode = Browse })
    scroll step = modify (\s -> s { stMode = ViewFile path content (max 0 (min (length (T.lines content)) (offset + step))) })
    scrollPage direction = do
      st <- get
      scroll (direction * max 1 (snd (stTerminalSize st) - 4))
