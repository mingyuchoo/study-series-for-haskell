module Hfm.Infrastructure.Config
  ( getConfigPath, loadKeyBindingConfig, decodeKeyBindingConfig
  , getSettingsPath, loadSettings, loadSettingsFrom, saveSettings, saveSettingsTo, decodeSettings
  ) where

import Control.Exception (IOException, try, bracketOnError)
import qualified Data.ByteString as BS
import Data.Text (Text)
import qualified Data.Text as T
import Data.Yaml (FromJSON (..), ToJSON (..), ParseException, decodeEither', encode, withObject, object, (.=), (.!=), (.:?))
import Hfm.Application.Error (FileError (..))
import Hfm.Domain.Config
import Hfm.Domain.Language (Language (..))
import Hfm.Domain.Theme (themes)
import Hfm.Infrastructure.Ports (capture, formatFileError)
import System.Directory (XdgDirectory (..), doesFileExist, getXdgDirectory, createDirectoryIfMissing, renameFile, removeFile)
import System.FilePath ((</>), takeDirectory)
import System.IO (openBinaryTempFile, hClose)
import System.IO.Error (isDoesNotExistError)

newtype StoredSettings = StoredSettings Settings

instance FromJSON StoredSettings where
  parseJSON = withObject "Settings" $ \v -> do
    editor <- v .:? "editor"
    language <- v .:? "language" .!= "ko"
    theme <- v .:? "theme" .!= "dark"
    selectedLanguage <- case (language :: Text) of
      "ko" -> pure Korean
      "en" -> pure English
      _ -> fail "Unsupported language; expected ko or en"
    selectedTheme <- case lookup theme [(T.toLower (T.pack (show t)), t) | t <- themes] of
      Just t -> pure t
      Nothing -> fail "Unsupported theme"
    case editor of
      Just value | not (validEditor value) -> fail "Invalid editor path"
      _ -> pure ()
    let executable = editor >>= \value ->
          if T.null (T.strip value) then Nothing else Just (T.unpack (T.strip value))
    pure (StoredSettings (Settings executable selectedLanguage selectedTheme))

instance ToJSON StoredSettings where
  toJSON (StoredSettings settings) = object
    [ "editor" .= settingsEditor settings
    , "language" .= (if settingsLanguage settings == Korean then "ko" else "en" :: Text)
    , "theme" .= T.toLower (T.pack (show (settingsTheme settings)))
    ]

decodeSettings :: BS.ByteString -> Either ParseException Settings
decodeSettings bytes = do
  StoredSettings settings <- decodeEither' bytes
  pure settings

getSettingsPath :: IO FilePath
getSettingsPath = (</> "settings.yaml") <$> getXdgDirectory XdgConfig "hfm"

loadSettings :: IO (Either FileError Settings)
loadSettings = do
  result <- capture getSettingsPath
  either (pure . Left) loadSettingsFrom result

loadSettingsFrom :: FilePath -> IO (Either FileError Settings)
loadSettingsFrom path = do
  result <- try (BS.readFile path) :: IO (Either IOException BS.ByteString)
  pure $ case result of
    Left err | isDoesNotExistError err -> Right defaultSettings
             | otherwise -> Left (formatFileError err)
    Right bytes -> either (Left . FileFailure . T.pack . show) Right (decodeSettings bytes)

saveSettings :: Settings -> IO (Either FileError ())
saveSettings settings = do
  result <- capture getSettingsPath
  either (pure . Left) (`saveSettingsTo` settings) result

saveSettingsTo :: FilePath -> Settings -> IO (Either FileError ())
saveSettingsTo path settings = capture $ do
  case settingsEditor settings of
    Just editor | not (validEditor (T.pack editor)) -> ioError (userError "Invalid editor path")
    _ -> pure ()
  let directory = takeDirectory path
  createDirectoryIfMissing True directory
  -- Replace only after writing successfully so a failed save preserves the previous settings.
  bracketOnError (openBinaryTempFile directory "settings.yaml.tmp")
    (\(temporary, handle) -> hClose handle >> removeFile temporary)
    (\(temporary, handle) -> do
      BS.hPut handle (encode (StoredSettings settings))
      hClose handle
      renameFile temporary path)

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
