module Chapter03.TypesAndTypeclasses
  where

-- | removeNonUppercase
-- >>> removeNonUppercase "Hello, Haskell!"
-- "HH"
-- >>> removeNonUppercase ""
-- ""
removeNonUppercase1 :: [Char] -> [Char]
removeNonUppercase1 s = [c | c <- s, c `elem` ['A' .. 'Z']]

removeNonUppercase2 :: [Char] -> [Char]
removeNonUppercase2 [] = []
removeNonUppercase2 (c : cs)
  | elem c ['A' .. 'Z'] = c : removeNonUppercase2 cs
  | otherwise = removeNonUppercase2 cs

removeNonUppercase3 :: [Char] -> [Char]
removeNonUppercase3 s = filter (\c -> elem c ['A' .. 'Z']) s

removeNonUppercase4 :: [Char] -> [Char]
removeNonUppercase4 s =
  foldr
    ( \c acc ->
        if elem c ['A' .. 'Z']
          then c : acc
          else acc
    )
    []
    s

-- | addThree
-- >>> addThree 1 1 1
-- 3
-- >>> addThree 1 2 3
-- 6
-- >>> addThree (-1) (-2) 3
-- 0
addThree :: (Num a) => a -> a -> a -> a
addThree x y z = x + y + z -- function pattern matching

-- | circumference
-- >>> circumference 4.0
-- 25.132741228718345
circumference :: (Floating a) => a -> a
circumference r = 2 * pi * r
