module Infrastructure.Configuration
  ( loadLanguage
  , loadKeyBindings
  , loadKeyBindingsWithMessages
  ) where

import Config (KeyBindings, defaultKeyBindings)
import Data.ByteString qualified as BS
import Data.Map.Strict qualified as Map
import Data.Yaml qualified as Yaml
import Flow ((<|))
import I18n qualified
import System.Directory (doesFileExist)
import System.FilePath ((</>))

loadKeyBindings :: FilePath -> IO KeyBindings
loadKeyBindings path = loadKeyBindingsWithMessages path I18n.defaultMessages

loadKeyBindingsWithMessages :: FilePath -> I18n.I18nMessages -> IO KeyBindings
loadKeyBindingsWithMessages path msgs = do
  let sysMsgs = I18n.messages msgs
  exists <- doesFileExist path
  if exists
    then loadFromFile sysMsgs
    else pure defaultKeyBindings
  where
    loadFromFile sysMsgs = do
      content <- BS.readFile path
      case Yaml.decodeEither' content of
        Left err -> do
          putStrLn <| I18n.config_load_failed sysMsgs <> ": " <> show err
          putStrLn <| I18n.using_default sysMsgs
          pure defaultKeyBindings
        Right kb -> do
          putStrLn <| I18n.config_loaded sysMsgs
          pure kb

loadLanguage :: FilePath -> IO I18n.Language
loadLanguage configDir = do
  let path = configDir </> "settings.yaml"
  exists <- doesFileExist path
  if exists
    then do
      content <- BS.readFile path
      case Yaml.decodeEither' content :: Either Yaml.ParseException (Map.Map String String) of
        Right m -> case Map.lookup "language" m of
          Just lang -> pure <| I18n.stringToLanguage lang
          Nothing -> pure I18n.Korean
        Left problem -> do
          putStrLn $ "settings.yaml: " <> show problem
          pure I18n.Korean
    else pure I18n.Korean
