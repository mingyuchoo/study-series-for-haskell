module Event
    ( formatFileError
    , formatPreviewError
    , handleEvent
    , loadFileContent
    , loadSelectedFile
    , toSessionEvent
    ) where

import           Brick

import           Config                 (KeyBindingStyle (..))

import           Control.Exception      (IOException, try)
import           Control.Monad.IO.Class (liftIO)

import qualified Data.Text              as T
import qualified Data.Text.IO           as TIO

import qualified Fzh.Domain.Search      as Search
import           Fzh.Domain.Session

import qualified Graphics.Vty           as V

import           System.IO.Error        (isDoesNotExistError, isPermissionError)

import           Types

toSessionEvent :: KeyBindingStyle -> V.Event -> Maybe SessionEvent
toSessionEvent binding event = case event of
  V.EvResize width height               -> Just (TerminalResized width height)
  V.EvKey V.KEsc []                     -> Just Dismiss
  V.EvKey V.KEnter []                   -> Just Confirm
  V.EvKey V.KUp []                      -> Just (Navigate Search.Previous)
  V.EvKey V.KDown []                    -> Just (Navigate Search.Next)
  V.EvKey (V.KChar 'u') [V.MCtrl]       -> Just (EditQuery Clear)
  V.EvKey V.KBS []                      -> Just (EditQuery Delete)
  V.EvKey (V.KChar character) []        -> Just (EditQuery (Append character))
  V.EvKey (V.KChar character) [V.MCtrl] -> styleEvent binding character
  _                                     -> Nothing

styleEvent :: KeyBindingStyle -> Char -> Maybe SessionEvent
styleEvent Emacs character = case character of
  'p' -> Just (Navigate Search.Previous)
  'n' -> Just (Navigate Search.Next)
  'g' -> Just Dismiss
  'h' -> Just (EditQuery Delete)
  _   -> Nothing
styleEvent Vim character = case character of
  'k' -> Just (Navigate Search.Previous)
  'j' -> Just (Navigate Search.Next)
  'c' -> Just Dismiss
  'w' -> Just (EditQuery Delete)
  _   -> Nothing

handleEvent :: BrickEvent Name e -> EventM Name AppState ()
handleEvent (VtyEvent event) = do
  state <- get
  maybe (pure ()) dispatch (toSessionEvent (configKeyBinding (stConfig state)) event)
handleEvent _ = pure ()

loadSelectedFile :: EventM Name AppState ()
loadSelectedFile = dispatch RequestPreview

dispatch :: SessionEvent -> EventM Name AppState ()
dispatch event = do
  state <- get
  let (next, commands) = transitionApp event state
  put next
  mapM_ execute commands
  where
    execute StopSession = halt
    execute (ReadPreview request@(PreviewRequest _ path)) = do
      result <- liftIO (loadFileContent path)
      dispatch (PreviewCompleted request result)

previewError :: IOException -> PreviewError
previewError problem
  | isDoesNotExistError problem = MissingFile
  | isPermissionError problem = PermissionDenied
  | otherwise = ReadError (show problem)

formatPreviewError :: PreviewError -> T.Text
formatPreviewError MissingFile        = "파일이 존재하지 않습니다"
formatPreviewError PermissionDenied   = "파일 읽기 권한이 없습니다"
formatPreviewError (ReadError detail) = "파일 읽기 오류: " <> T.pack detail

formatFileError :: IOException -> T.Text
formatFileError = formatPreviewError . previewError

loadFileContent :: FilePath -> IO (Either PreviewError String)
loadFileContent path = either (Left . previewError) (Right . T.unpack) <$> try (TIO.readFile path)
