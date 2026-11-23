module Lib
  ( someFunc
  ) where

import Diagrams.Backend.SVG.CmdLine
import Diagrams.Prelude

someFunc :: IO ()
someFunc = mainWith demoDiagram

demoDiagram :: Diagram B
demoDiagram =
  hcat
    [ circle 1
    , square 1
    , triangle 1
    ]
    # fc blue
