module Fzh.Domain.Search
  ( Search
  , Direction (..)
  , newSearch
  , allItems
  , query
  , results
  , selectedIndex
  , selectedItem
  , updateQuery
  , moveSelection
  , fuzzyMatchScore
  , filterItems
  ) where

import Data.List (sortOn)
import Fzh.Domain.Unicode (lowercase)

data Search = Search
  { allItems :: [String]
  , query :: String
  , results :: [String]
  , cursor :: !Cursor
  }
  deriving (Eq, Show)

data Direction = Previous | Next
  deriving (Eq, Show)

data Cursor = EmptyCursor | Cursor !Int [String] String [String]
  deriving (Eq, Show)

newSearch :: [String] -> Search
newSearch items = Search items "" items (firstCursor items)

firstCursor :: [String] -> Cursor
firstCursor [] = EmptyCursor
firstCursor (item : remaining) = Cursor 0 [] item remaining

selectedIndex :: Search -> Maybe Int
selectedIndex search = case cursor search of
  EmptyCursor -> Nothing
  Cursor index _ _ _ -> Just index

selectedItem :: Search -> Maybe String
selectedItem search = case cursor search of
  EmptyCursor -> Nothing
  Cursor _ _ item _ -> Just item

updateQuery :: String -> Search -> Search
updateQuery value search =
  let matches = filterItems value (allItems search)
   in search {query = value, results = matches, cursor = firstCursor matches}

moveSelection :: Direction -> Search -> Search
moveSelection direction search = search {cursor = move (cursor search)}
  where
    move current = case (direction, current) of
      (Previous, Cursor index (previous : remaining) item following) -> Cursor (index - 1) remaining previous (item : following)
      (Next, Cursor index previous item (following : remaining)) -> Cursor (index + 1) (item : previous) following remaining
      _ -> current

fuzzyMatchScore :: String -> String -> Maybe Int
fuzzyMatchScore needle value = match (lowercase needle) (lowercase value) 0
  where
    match [] _ gaps = Just gaps
    match _ [] _ = Nothing
    match remaining@(expected : rest) (character : characters) gaps
      | expected == character = match rest characters gaps
      | otherwise = match remaining characters (gaps + 1)

filterItems :: String -> [String] -> [String]
filterItems "" items = items
filterItems needle items = map snd (sortOn fst scored)
  where
    scored =
      [ ((score, pathDepth item), item)
      | item <- items
      , Just score <- [fuzzyMatchScore needle item]
      ]
    pathDepth = length . filter (\character -> character == '/' || character == '\\')
