{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

module Config
  ( KeyAction (..)
  , KeyBindings (..)
  , defaultKeyBindings
  , getFirstKey
  , keyToString
  , matchesKey
  , matchesKeyFor
  , matchesKeyWithMods
  ) where

import Data.Aeson (FromJSON, parseJSON, withObject, (.:))
import Data.List (find)

import Flow ((<|))

import GHC.Generics (Generic)

import Graphics.Vty qualified as V

data KeyAction
  = QuitApp
  | AddTodo
  | ToggleComplete
  | DeleteTodo
  | NavigateUp
  | NavigateDown
  | SaveInput
  | CancelInput
  | EditTodo
  deriving (Eq, Generic, Show)

data KeyBindings = KeyBindings
  { quit :: ![String]
  , add_todo :: ![String]
  , toggle_complete :: ![String]
  , delete_todo :: ![String]
  , navigate_up :: ![String]
  , navigate_down :: ![String]
  , save_input :: ![String]
  , cancel_input :: ![String]
  , edit_todo :: ![String]
  }
  deriving (Generic, Show)

instance FromJSON KeyBindings where
  parseJSON =
    withObject "KeyBindings" <| \v -> do
      kb <- v .: "keybindings"
      KeyBindings
        <$> kb .: "quit"
        <*> kb .: "add_todo"
        <*> kb .: "toggle_complete"
        <*> kb .: "delete_todo"
        <*> kb .: "navigate_up"
        <*> kb .: "navigate_down"
        <*> kb .: "save_input"
        <*> kb .: "cancel_input"
        <*> kb .: "edit_todo"

defaultKeyBindings :: KeyBindings
defaultKeyBindings =
  KeyBindings
    { quit = ["q", "Esc"]
    , add_todo = ["a"]
    , toggle_complete = ["Space"]
    , delete_todo = ["d"]
    , navigate_up = ["Up", "k"]
    , navigate_down = ["Down", "j"]
    , save_input = ["Enter"]
    , cancel_input = ["Esc"]
    , edit_todo = ["e"]
    }

keyToString :: V.Key -> String
keyToString = \case
  V.KChar ' ' -> "Space"
  V.KChar c -> [c]
  V.KEnter -> "Enter"
  V.KEsc -> "Esc"
  V.KUp -> "Up"
  V.KDown -> "Down"
  V.KLeft -> "Left"
  V.KRight -> "Right"
  V.KBS -> "Backspace"
  V.KFun n -> "F" <> show n
  _ -> ""

keyWithModsToString :: V.Key -> [V.Modifier] -> String
keyWithModsToString key mods
  | V.MCtrl `elem` mods = case key of
      V.KChar c -> "C-" <> [c]
      _ -> keyToString key
  | otherwise = keyToString key

matchesKey :: KeyBindings -> V.Key -> Maybe KeyAction
matchesKey kb key = matchesKeyWithMods kb key []

matchesKeyWithMods :: KeyBindings -> V.Key -> [V.Modifier] -> Maybe KeyAction
matchesKeyWithMods =
  matchesKeyFor
    [ QuitApp
    , AddTodo
    , ToggleComplete
    , DeleteTodo
    , NavigateUp
    , NavigateDown
    , SaveInput
    , CancelInput
    , EditTodo
    ]

matchesKeyFor :: [KeyAction] -> KeyBindings -> V.Key -> [V.Modifier] -> Maybe KeyAction
matchesKeyFor allowed kb key mods =
  snd <$> find (\(keys, action) -> action `elem` allowed && keyMatches keyStr keys) actions
  where
    keyStr = keyWithModsToString key mods
    keyMatches str keys = str `elem` keys
    actions =
      [ (quit kb, QuitApp)
      , (add_todo kb, AddTodo)
      , (toggle_complete kb, ToggleComplete)
      , (delete_todo kb, DeleteTodo)
      , (navigate_up kb, NavigateUp)
      , (navigate_down kb, NavigateDown)
      , (save_input kb, SaveInput)
      , (cancel_input kb, CancelInput)
      , (edit_todo kb, EditTodo)
      ]

getFirstKey :: [String] -> String -> String
getFirstKey [] def = def
getFirstKey (k : _) _def = k
