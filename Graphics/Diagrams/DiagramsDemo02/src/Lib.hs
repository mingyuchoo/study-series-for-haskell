module Lib
  ( someFunc
  ) where

import Diagrams.Backend.SVG.CmdLine
import Diagrams.Prelude

someFunc :: IO ()
someFunc = mainWith tree

tree :: Diagram B
tree =
  circle 0.2 # fc red
    <> square 0.5 # fc brown # translateY (-0.5)
