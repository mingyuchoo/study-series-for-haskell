module App
  ( runApp
  ) where

import App.Config (appConfig)
import App.Model (initialModel)
import App.Update (handleEvent)
import App.View (buildUI)
import Monomer (startApp)
import System.IO (BufferMode (NoBuffering), hSetBuffering, stdout)

runApp :: IO ()
runApp = do
  hSetBuffering stdout NoBuffering
  startApp initialModel handleEvent buildUI appConfig
