module Lib
  ( someFunc
  ) where

import Graphics.Gloss

someFunc :: IO ()
someFunc = display window white picture
  where
    window = InWindow "My Window" (400, 400) (100, 100)
    picture = Circle 80
