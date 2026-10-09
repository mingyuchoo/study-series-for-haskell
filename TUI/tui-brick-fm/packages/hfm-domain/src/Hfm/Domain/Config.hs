module Hfm.Domain.Config
  ( KeyBindingStyle (..), KeyBindingConfig (..), defaultKeyBindingConfig, parseBindingStyle
  , Settings (..), defaultSettings, validEditor ) where

import Data.Text (Text)
import qualified Data.Text as T
import Hfm.Domain.Language (Language (Korean))
import Hfm.Domain.Theme (Theme (Dark))

data Settings = Settings
  { settingsEditor :: Maybe FilePath
  , settingsLanguage :: Language
  , settingsTheme :: Theme
  } deriving (Eq, Show)

defaultSettings :: Settings
defaultSettings = Settings Nothing Korean Dark

validEditor :: Text -> Bool
validEditor = not . T.any (`elem` ['\0', '\n', '\r'])

data KeyBindingStyle = Emacs deriving (Eq, Show)
data KeyBindingConfig = KeyBindingConfig { bindingStyle :: KeyBindingStyle } deriving (Eq, Show)

defaultKeyBindingConfig :: KeyBindingConfig
defaultKeyBindingConfig = KeyBindingConfig Emacs

-- Legacy Vim and unknown values are intentionally normalized to Emacs.
parseBindingStyle :: Text -> KeyBindingStyle
parseBindingStyle _ = Emacs
