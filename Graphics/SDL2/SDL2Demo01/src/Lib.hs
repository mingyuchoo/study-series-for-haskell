module Lib
  ( someFunc
  ) where

import Control.Concurrent (threadDelay)
import Data.Text qualified as T
import Linear (V2 (..), V4 (..))
import Linear.Affine (Point (P))
import SDL

someFunc :: IO ()
someFunc = do
  initializeAll
  window <- createWindow (T.pack "SDL2") defaultWindow
  renderer <- createRenderer window (-1) defaultRenderer

  appLoop renderer

  destroyRenderer renderer
  destroyWindow window
  quit

appLoop :: Renderer -> IO ()
appLoop renderer = do
  rendererDrawColor renderer $= V4 0 0 255 255
  clear renderer

  rendererDrawColor renderer $= V4 255 0 0 255
  fillRect renderer (Just $ Rectangle (P (V2 100 100)) (V2 50 50))

  present renderer

  threadDelay 1000000
