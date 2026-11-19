module Fzh.Domain.Config
  ( KeyBindingStyle (..)
  , KeyBindingConfig (..)
  , ConfigResult (..)
  , defaultKeyBindingConfig
  , parseBindingStyle
  , resolvedConfig
  ) where

import Fzh.Domain.Unicode (lowercase)

data KeyBindingStyle = Emacs | Vim
  deriving (Eq, Show)

newtype KeyBindingConfig = KeyBindingConfig {bindingStyle :: KeyBindingStyle}
  deriving (Eq, Show)

data ConfigResult = ConfigLoaded KeyBindingConfig | ConfigMissing | ConfigInvalid String
  deriving (Eq, Show)

defaultKeyBindingConfig :: KeyBindingConfig
defaultKeyBindingConfig = KeyBindingConfig Emacs

parseBindingStyle :: String -> KeyBindingStyle
parseBindingStyle value = case lowercase value of
  "vim" -> Vim
  "vi" -> Vim
  _ -> Emacs

resolvedConfig :: ConfigResult -> KeyBindingConfig
resolvedConfig result = case result of
  ConfigLoaded config -> config
  ConfigMissing -> defaultKeyBindingConfig
  ConfigInvalid _ -> defaultKeyBindingConfig
