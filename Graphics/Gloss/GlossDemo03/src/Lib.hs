module Lib
  ( someFunc
  ) where

import Graphics.Gloss.Interface.Pure.Game

-- 인터랙티브 예제
someFunc :: IO ()
someFunc = play window white 60 initialState render handleEvent update
  where
    window = InWindow "Game" (400, 400) (100, 100)

    initialState = (0, 0) -- (x, y) position
    render (x, y) = Translate x y (Circle 20)

    handleEvent (EventKey (SpecialKey KeyUp) Down _ _) (x, y)    = (x, y + 10)
    handleEvent (EventKey (SpecialKey KeyDown) Down _ _) (x, y)  = (x, y - 10)
    handleEvent (EventKey (SpecialKey KeyRight) Down _ _) (x, y) = (x + 10, y)
    handleEvent (EventKey (SpecialKey KeyLeft) Down _ _) (x, y)  = (x - 10, y)
    handleEvent _ state                                          = state

    update _ state = state
