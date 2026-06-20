module Lib
  ( someFunc
  ) where

import Diagrams.Backend.SVG.CmdLine
import Diagrams.Prelude

someFunc :: IO ()
someFunc = mainWith example

example :: Diagram B
example = circle 1 # fc blue # lw 0.05
