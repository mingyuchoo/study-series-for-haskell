module Hfm.Domain.Selection
  ( Selection, selection, selectionItems, selectionIndex, selectedElement, selectAt, selectStep ) where

import qualified Data.Vector as Vec

-- The constructor is private so every selection is empty or within bounds.
data Selection a = Selection (Vec.Vector a) (Maybe Int) deriving (Eq, Show)

selection :: [a] -> Selection a
selection xs = Selection (Vec.fromList xs) (if null xs then Nothing else Just 0)

selectionItems :: Selection a -> Vec.Vector a
selectionItems (Selection xs _) = xs

selectionIndex :: Selection a -> Maybe Int
selectionIndex (Selection _ index) = index

selectedElement :: Selection a -> Maybe (Int, a)
selectedElement (Selection xs index) = do
  i <- index
  value <- xs Vec.!? i
  pure (i, value)

-- Negative indices count from the end, matching the existing End-key behavior.
selectAt :: Int -> Selection a -> Selection a
selectAt index (Selection xs _) =
  let count = Vec.length xs
      requested = if index < 0 then count + index else index
  in Selection xs (if count == 0 then Nothing else Just (max 0 (min (count - 1) requested)))

selectStep :: Int -> Selection a -> Selection a
selectStep step selected = selectAt (max 0 (maybe 0 id (selectionIndex selected) + step)) selected
