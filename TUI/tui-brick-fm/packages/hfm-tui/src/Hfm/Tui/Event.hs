module Hfm.Tui.Event (handleEvent) where

import Brick (BrickEvent (..), EventM, get, put, halt, suspendAndResume')
import Control.Monad (when)
import Control.Monad.IO.Class (liftIO)
import Hfm.Application.Effects.Ports (FileSystem (..), Processes (..))
import Hfm.Application.Error (FileError)
import Hfm.Domain.Config (Settings)
import Hfm.Tui.Name
import Hfm.Application.State
import Hfm.Application.Effects.Runtime (handleInput)
import Hfm.Tui.Input (fromVty)
import Hfm.Tui.Layout (prepareLayout)
import Hfm.Tui.Terminal (waitForReturn)
import Hfm.Tui.I18n (translate)

handleEvent :: FileSystem IO -> Processes IO -> (Settings -> IO (Either FileError ())) -> BrickEvent Name e -> EventM Name AppState ()
handleEvent files processes save (VtyEvent input) = do
  state <- prepareLayout <$> get
  let eventFiles = FileSystem
        { readEntries = \hidden path -> liftIO (readEntries files hidden path)
        , canonicalizePath = liftIO . canonicalizePath files
        , doesDirectoryExist = liftIO . doesDirectoryExist files
        , readPreview = liftIO . readPreview files
        , copyEntry = \source target -> liftIO (copyEntry files source target)
        , moveEntry = \source target -> liftIO (moveEntry files source target)
        , deleteEntry = liftIO . deleteEntry files
        , makeDirectory = liftIO . makeDirectory files
        }
      eventProcesses = Processes
        { editFile = \editor cwd path -> suspendAndResume' (editFile processes editor cwd path)
        , runCommand = \cwd command -> suspendAndResume' $ do
            result <- runCommand processes cwd command
            waitForReturn (translate (stLanguage state) "Enter를 누르면 파일 관리자로 돌아갑니다.")
            pure result
        }
  (updated, quit) <- handleInput eventFiles eventProcesses (liftIO . save) (fromVty input) state
  put (prepareLayout updated)
  when quit halt
handleEvent _ _ _ _ = pure ()
