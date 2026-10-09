module Hfm.Tui.Event (handleEvent) where

import Brick (BrickEvent (..), EventM, get, put, halt, suspendAndResume')
import Control.Monad (when)
import Control.Monad.IO.Class (liftIO)
import Hfm.Application.Ports (FileSystem (..))
import Hfm.Tui.Name
import Hfm.Application.State
import Hfm.Application.UseCases (handleInput)
import Hfm.Tui.Input (fromVty)
import Hfm.Tui.Layout (prepareLayout)
import Hfm.Tui.Terminal (waitForReturn)
import Hfm.Tui.I18n (translate)

handleEvent :: FileSystem IO -> BrickEvent Name e -> EventM Name AppState ()
handleEvent ports (VtyEvent input) = do
  state <- prepareLayout <$> get
  let eventPorts = FileSystem
        { readEntries = \hidden path -> liftIO (readEntries ports hidden path)
        , canonicalizePath = liftIO . canonicalizePath ports
        , doesDirectoryExist = liftIO . doesDirectoryExist ports
        , readPreview = liftIO . readPreview ports
        , copyEntry = \source target -> liftIO (copyEntry ports source target)
        , moveEntry = \source target -> liftIO (moveEntry ports source target)
        , deleteEntry = liftIO . deleteEntry ports
        , makeDirectory = liftIO . makeDirectory ports
        , editFile = \cwd path -> suspendAndResume' (editFile ports cwd path)
        , runCommand = \cwd command -> suspendAndResume' $ do
            result <- runCommand ports cwd command
            waitForReturn (translate (stLanguage state) "Enter를 누르면 파일 관리자로 돌아갑니다.")
            pure result
        }
  (updated, quit) <- handleInput eventPorts (fromVty input) state
  put (prepareLayout updated)
  when quit halt
handleEvent _ _ = pure ()
