module Fzh.Domain.Unicode (lowercase) where

import Data.Char (toLower)

lowercase :: String -> String
lowercase = concatMap lowerCharacter
  where
    lowerCharacter '\x0130' = "i\x0307"
    lowerCharacter character = [toLower character]
