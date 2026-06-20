module Chapter05.Recursion
  where

-- | maximum'
-- >>> maximum' [1,2,3,4,5]
-- 5
maximum' :: (Ord a) => [a] -> a
maximum' [] = error "maximum of empty list"
maximum' [x] = x
maximum' (x : xs)
  | x > maximum' xs = x
  | otherwise = maximum' xs

-- | maximum''
-- >>> maximum'' [1,2,3,4,5]
-- 5
maximum'' :: (Ord a) => [a] -> a
maximum'' [] = error "maximum of empty list"
maximum'' [x] = x
maximum'' (x : xs)
  | x > maxTail = x
  | otherwise = maxTail
  where
    maxTail = maximum' xs

-- | maximum'''
-- >>> maximum''' [1,2,3,4,5]
-- 5
maximum''' :: (Ord a) => [a] -> a
maximum''' []       = error "maximum of empty list"
maximum''' [x]      = x
maximum''' (x : xs) = max x (maximum' xs)

-- | replicate'
-- >>> replicate' 3 'a'
-- "aaa"
-- >>> replicate' 3 5
-- [5,5,5]
replicate' :: (Num i, Ord i) => i -> a -> [a]
replicate' n x
  | n <= 0 = []
  | otherwise = x : replicate' (n - 1) x

-- | take'
-- >>> take' 3 [1,2,3,4,5]
-- [1,2,3]
take' :: (Num i, Ord i) => i -> [a] -> [a]
take' n _ | n <= 0 = []
take' _ [] = []
take' n (x : xs) = x : take' (n - 1) xs

-- | reverse'
-- >>> reverse' [1,2,3,4,5]
-- [5,4,3,2,1]
reverse' :: [a] -> [a]
reverse' []       = []
reverse' (x : xs) = reverse' xs ++ [x]

-- | zip'
-- >>> zip' [1,2] ['a','b']
-- [(1,'a'),(2,'b')]
zip' :: [a] -> [b] -> [(a, b)]
zip' _ []              = []
zip' [] _              = []
zip' (x : xs) (y : ys) = (x, y) : zip' xs ys

-- | elem'
-- >>> elem' 3 [1, 2, 3]
-- True
-- >>> elem' 4 [1, 3, 3]
-- False
elem' :: (Eq a) => a -> [a] -> Bool
elem' a [] = False
elem' a (x : xs)
  | a == x = True
  | otherwise = elem' a xs
