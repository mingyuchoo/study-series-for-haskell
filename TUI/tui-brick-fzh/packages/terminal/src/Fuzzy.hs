module Fuzzy
    ( filterItems
    , fuzzyMatchScore
    ) where

import qualified Data.Text         as T
import qualified Data.Vector       as Vec

import qualified Fzh.Domain.Search as Search

fuzzyMatchScore :: T.Text -> T.Text -> Maybe Int
fuzzyMatchScore query value = Search.fuzzyMatchScore (T.unpack query) (T.unpack value)

filterItems :: T.Text -> Vec.Vector T.Text -> Vec.Vector T.Text
filterItems query =
  Vec.fromList
    . map T.pack
    . Search.filterItems (T.unpack query)
    . map T.unpack
    . Vec.toList
