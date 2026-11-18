module Main
  ( main
  ) where

import App qualified

import Brick (defaultMain)
import Brick.Widgets.Edit qualified as E
import Brick.Widgets.List (list)

import Config qualified

import Control.Exception (bracket)
import Control.Monad (void)

import DB qualified

import Data.ByteString qualified as BS
import Data.Map.Strict qualified as Map
import Data.Vector qualified as Vec
import Data.Yaml qualified as Yaml

import Database.SQLite.Simple (close, open)

import Flow ((<|))

import I18n qualified

import Lib

import System.Directory
  ( createDirectoryIfMissing
  , doesFileExist
  , getHomeDirectory
  )
import System.FilePath ((</>))
import System.IO
  ( BufferMode (NoBuffering)
  , hSetBuffering
  , stdout
  )

import TodoService qualified

projectName :: String
projectName = "tto"

getConfigDir :: IO FilePath
getConfigDir = do
  homeDir <- getHomeDirectory
  let configDir = homeDir </> ".config" </> projectName
  createDirectoryIfMissing True configDir
  return configDir

getDBPath :: IO FilePath
getDBPath = do
  configDir <- getConfigDir
  return <| configDir </> "todos.db"

getKeyBindingsPath :: IO FilePath
getKeyBindingsPath = do
  configDir <- getConfigDir
  return <| configDir </> "keybindings.yaml"

-- | 설정 파일에서 언어를 읽어옴 (Effectful)
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
        Left _ -> pure I18n.Korean
    else pure I18n.Korean

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  configDir <- getConfigDir
  lang <- loadLanguage configDir
  runApp configDir lang

runApp :: FilePath -> I18n.Language -> IO ()
runApp configDir lang = do
  msgs <- I18n.loadMessages configDir lang
  kbPath <- getKeyBindingsPath
  kb <- Config.loadKeyBindingsWithMessages kbPath msgs

  dbPath <- getDBPath
  bracket (open dbPath) close <| \conn -> do
    DB.initDBWithMessages conn msgs

    -- Create AppEnv with all dependencies
    let env =
          App.AppEnv
            { App.envConnection = conn
            , App.envMessages = msgs
            , App.envKeyBindings = kb
            }

    -- Load todos using Tagless Final
    todoRows <- App.runAppM env TodoService.loadAllTodos

    let initialTodos = Vec.fromList <| map fromTodoRow todoRows
        initialState =
          AppState
            { _todoList = list TodoList initialTodos 1
            , _actionEditor = E.editor ActionField (Just 1) ""
            , _subjectEditor = E.editor SubjectField (Just 1) ""
            , _indirectObjectEditor = E.editor IndirectObjectField (Just 1) ""
            , _directObjectEditor = E.editor DirectObjectField (Just 1) ""
            , _focusedField = FocusAction
            , _mode = ViewMode
            , _appEnv = env
            , _editingIndex = Nothing
            , _i18nMessages = msgs
            , _errorMessage = Nothing
            }

    void <| defaultMain app initialState
