module Hfm.Domain.Config
  ( KeyBindingStyle (..), KeyBindingConfig (..), defaultKeyBindingConfig, parseBindingStyle ) where

import Data.Text (Text)

data KeyBindingStyle = Emacs deriving (Eq, Show)
data KeyBindingConfig = KeyBindingConfig { bindingStyle :: KeyBindingStyle } deriving (Eq, Show)

defaultKeyBindingConfig :: KeyBindingConfig
defaultKeyBindingConfig = KeyBindingConfig Emacs

-- Legacy Vim and unknown values are intentionally normalized to Emacs.
parseBindingStyle :: Text -> KeyBindingStyle
parseBindingStyle _ = Emacs
