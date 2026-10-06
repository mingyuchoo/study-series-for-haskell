module Hfm.Domain.Editor (editText) where

import Data.Char (isAlphaNum)
import qualified Data.Text as T
import Hfm.Domain.Input

-- | Edit a one-line input. Cursor positions count Text characters, not bytes.
editText :: Input -> T.Text -> Int -> Maybe (T.Text, Int)
editText event value rawCursor = case normalizeMeta event of
  KeyPress (KChar 'a') [MCtrl] -> Just (value, 0)
  KeyPress (KChar 'e') [MCtrl] -> Just (value, T.length value)
  KeyPress (KChar 'b') [MCtrl] -> Just (value, max 0 (cursor - 1))
  KeyPress (KChar 'f') [MCtrl] -> Just (value, min (T.length value) (cursor + 1))
  KeyPress (KChar 'b') [MMeta] -> Just (value, wordStart)
  KeyPress (KChar 'f') [MMeta] -> Just (value, wordEnd)
  KeyPress KHome [] -> Just (value, 0)
  KeyPress KEnd [] -> Just (value, T.length value)
  KeyPress KLeft [] -> Just (value, max 0 (cursor - 1))
  KeyPress KRight [] -> Just (value, min (T.length value) (cursor + 1))
  KeyPress (KChar 'k') [MCtrl] -> Just (T.take cursor value, cursor)
  KeyPress (KChar 'w') [MCtrl] -> Just (T.take wordStart value <> T.drop cursor value, wordStart)
  KeyPress KBS [MMeta] -> Just (T.take wordStart value <> T.drop cursor value, wordStart)
  KeyPress (KChar 'd') [MMeta] -> Just (T.take cursor value <> T.drop wordEnd value, cursor)
  KeyPress (KChar 'h') [MCtrl] -> deleteBackward
  KeyPress KBS [] -> deleteBackward
  KeyPress (KChar 'd') [MCtrl] -> deleteForward
  KeyPress KDel [] -> deleteForward
  KeyPress (KChar c) [] -> Just (T.take cursor value <> T.singleton c <> T.drop cursor value, cursor + 1)
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
    afterCursor = T.drop cursor value
    wordEnd = T.length value - T.length (T.dropWhile isWordChar (T.dropWhile (not . isWordChar) afterCursor))
    isWordChar c = isAlphaNum c || c == '_'

