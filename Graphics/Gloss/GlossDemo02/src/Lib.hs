module Lib
  ( someFunc
  ) where

import Graphics.Gloss

-- 애니메이션 예제
someFunc :: IO ()
someFunc = animate window white frame
  where
    window = InWindow "Animation" (400, 400) (100, 100)

    frame time = Rotate (time * 30) (Circle 80)
