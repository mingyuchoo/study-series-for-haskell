module Hfm.Domain.Entry (Entry (..), EntryKind (..), sortEntries, visibleNames) where

import Data.List (sortBy)
import Data.Ord (comparing)
import qualified Data.Text as T

data EntryKind = Parent | Directory | RegularFile | SymbolicLink | Special deriving (Eq, Show)
data Entry = Entry
  { entryName :: FilePath
  , entryKind :: EntryKind
  , entrySize :: Integer
  } deriving (Eq, Show)

sortEntries :: [Entry] -> [Entry]
sortEntries = sortBy (comparing (\e -> (entryKind e /= Directory, T.toCaseFold (T.pack (entryName e)))))

visibleNames :: Bool -> [FilePath] -> [FilePath]
visibleNames showHidden = filter (\name -> showHidden || not ("." `T.isPrefixOf` T.pack name))
