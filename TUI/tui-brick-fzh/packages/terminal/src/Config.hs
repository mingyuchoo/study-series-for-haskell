module Config
  ( module Fzh.Domain.Config
  , getConfigPath
  , loadKeyBindingConfig
  , loadKeyBindingConfigFrom
  , loadConfiguration
  ) where

import Control.Exception (IOException, try)
import Data.ByteString qualified as BS
import Data.Text qualified as T
import Data.Yaml (FromJSON (..), decodeEither', withObject, (.!=), (.:?))
import Fzh.Domain.Config
import System.Directory (XdgDirectory (..), getXdgDirectory)
import System.FilePath ((</>))
import System.IO.Error (isDoesNotExistError)

newtype RawConfig = RawConfig KeyBindingConfig

instance FromJSON RawConfig where
  parseJSON = withObject "KeyBindingConfig" $ \value -> do
    style <- value .:? "binding_style" .!= ("emacs" :: T.Text)
    pure (RawConfig (KeyBindingConfig (parseBindingStyle (T.unpack style))))

loadKeyBindingConfigFrom :: FilePath -> IO ConfigResult
loadKeyBindingConfigFrom path = do
  result <- try (BS.readFile path)
  pure $ case result of
    Left (problem :: IOException)
      | isDoesNotExistError problem -> ConfigMissing
      | otherwise -> ConfigInvalid (show problem)
    Right bytes -> case decodeEither' bytes of
      Left problem -> ConfigInvalid (show problem)
      Right (RawConfig config) -> ConfigLoaded config

getConfigPath :: IO FilePath
getConfigPath = do
  directory <- getXdgDirectory XdgConfig "fzh"
  pure (directory </> "keybindings.yaml")

loadConfiguration :: IO ConfigResult
loadConfiguration = do
  result <- try getConfigPath
  either (pure . ConfigInvalid . show @IOException) loadKeyBindingConfigFrom result

loadKeyBindingConfig :: IO KeyBindingConfig
loadKeyBindingConfig = resolvedConfig <$> loadConfiguration
