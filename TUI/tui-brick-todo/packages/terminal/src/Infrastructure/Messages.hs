module Infrastructure.Messages (loadMessages) where

import Data.ByteString qualified as BS
import Data.Yaml qualified as Yaml
import Flow ((<|))
import I18n
import System.Directory (doesFileExist)
import System.FilePath ((</>))

loadMessages :: FilePath -> Language -> IO I18nMessages
loadMessages configDir lang = do
  let filename = case lang of
        English -> "messages-en.yaml"
        Korean -> "messages-ko.yaml"
      path = configDir </> filename
  exists <- doesFileExist path
  if exists
    then loadFromFile path
    else useDefault <| i18n_not_found (messages defaultMessages) <> ": " <> path
  where
    loadFromFile path = do
      content <- BS.readFile path
      case Yaml.decodeEither' content of
        Left err -> useDefault <| i18n_load_failed (messages defaultMessages) <> ": " <> show err
        Right msgs -> do
          putStrLn <| i18n_loaded (messages msgs)
          pure msgs

    useDefault msg = do
      putStrLn msg
      putStrLn <| using_default_lang (messages defaultMessages)
      pure defaultMessages
