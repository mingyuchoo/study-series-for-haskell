module Hfm.Tui.Event (handleEvent) where

import Brick (BrickEvent (..), EventM, get, put, halt)
import Control.Monad (when)
import Control.Monad.IO.Class (liftIO)
import Hfm.Application.Ports (FileSystem)
import Hfm.Tui.Name
import Hfm.Application.State
import Hfm.Application.UseCases (handleInput)
import Hfm.Tui.Input (fromVty)
import Hfm.Tui.Layout (prepareLayout)

handleEvent :: FileSystem IO -> BrickEvent Name e -> EventM Name AppState ()
handleEvent ports (VtyEvent input) = do
  state <- prepareLayout <$> get
  (updated, quit) <- liftIO (handleInput ports (fromVty input) state)
  put (prepareLayout updated)
  when quit halt
handleEvent _ _ = pure ()
