module Hfm.Infrastructure.Config (getConfigPath, loadKeyBindingConfig, decodeKeyBindingConfig) where

import Control.Exception (IOException, try)
import qualified Data.ByteString as BS
import Data.Text (Text)
import Data.Yaml (FromJSON (..), ParseException, decodeEither', withObject, (.!=), (.:?))
import Hfm.Domain.Config
import System.Directory (XdgDirectory (..), doesFileExist, getXdgDirectory)
import System.FilePath ((</>))

newtype RawConfig = RawConfig Text
instance FromJSON RawConfig where
  parseJSON = withObject "RawConfig" $ \v -> RawConfig <$> v .:? "binding_style" .!= "emacs"

decodeKeyBindingConfig :: BS.ByteString -> Either ParseException KeyBindingConfig
decodeKeyBindingConfig bytes = do
  RawConfig style <- decodeEither' bytes
  pure (KeyBindingConfig (parseBindingStyle style))

getConfigPath :: IO FilePath
getConfigPath = (</> "keybindings.yaml") <$> getXdgDirectory XdgConfig "hfm"

loadKeyBindingConfig :: IO KeyBindingConfig
loadKeyBindingConfig = do
  path <- getConfigPath
  exists <- doesFileExist path
  if exists
    then do
      result <- try (BS.readFile path) :: IO (Either IOException BS.ByteString)
      pure $ case result of
        Left _ -> defaultKeyBindingConfig
        Right bytes -> either (const defaultKeyBindingConfig) id (decodeKeyBindingConfig bytes)
    else pure defaultKeyBindingConfig
