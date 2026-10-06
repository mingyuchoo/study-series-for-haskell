module Hfm.Tui.Text (expandTabs) where

import Brick (textWidth)
import qualified Data.Text as T

-- Expand before rendering/tokenizing: terminal tabs move the cursor without
-- painting cells, and their width must not depend on borders or line numbers.
-- Count display cells so wide and combining characters keep the same tab stops.
expandTabs :: T.Text -> T.Text
expandTabs = T.concat . reverse . snd . T.foldl' expand (0, [])
  where
    expand (column, chunks) '\t' =
      let width = 8 - column `mod` 8
      in (column + width, T.replicate width " " : chunks)
    expand (_, chunks) '\n' = (0, "\n" : chunks)
    expand (column, chunks) char =
      let value = T.singleton char
      in (column + max 0 (textWidth value), value : chunks)
