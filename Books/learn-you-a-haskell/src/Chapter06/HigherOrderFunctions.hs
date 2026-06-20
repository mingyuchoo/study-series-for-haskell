module Chapter06.HigherOrderFunctions
  where

-- | multThree
multThree :: (Num a) => a -> a -> a -> a
multThree x y z = x * y * z

-- | compareWithHundred
-- :t compare         :: Ord a          => a -> a -> Ordering
-- :t (compare 100)   :: (Ord a, Num a) => a -> Ordering
-- :t (compare 100 1) :: Ordering
compareWithHundred :: (Num a, Ord a) => a -> Ordering
compareWithHundred x = compare 100 x

-- | compareWithHundred'
-- :t compare       :: Ord a          => a -> a -> Ordering
-- :t (compare 100) :: (Ord a, Num a) => a -> Ordering
compareWithHundred' :: (Num a, Ord a) => a -> Ordering
compareWithHundred' = compare 100

-- | divideByTen
-- :t (/)   :: Fractional a => a -> a -> a
-- :t (/10) :: Fractional a => a -> a
devideByTen :: (Floating a) => a -> a
devideByTen = (/ 10)

-- | isUpperAlphanum
isUpperAlphanum :: Char -> Bool
isUpperAlphanum = (`elem` ['A' .. 'Z'])

-- | isUpperAlphanum'
isUpperAlphanum' :: Char -> Bool
isUpperAlphanum' x = elem x ['A' .. 'Z']

-- | applyTwice
-- >>> applyTwice (+3) 10
-- 16
-- >>> applyTwice (++ " HAHA") "HEY"
-- "HEY HAHA HAHA"
-- >>> applyTwice ("HAHA " ++) "HEY"
-- "HAHA HAHA HEY"
-- >>> applyTwice (multThree 2 2) 9
-- 144
-- >>> applyTwice (3:) [1]
-- [3,3,1]
applyTwice :: (a -> a) -> a -> a
applyTwice f x = f (f x)

-- | zipWith'
-- >>> zipWith' (+) [4,2,5,6] [2,6,2,3]
-- [6,8,7,9]
-- >>> zipWith' max [6,3,2,1] [7,3,1,5]
-- [7,3,2,5]
-- >>> zipWith' (++) ["foo ", "bar ", "baz "] ["fighters", "hoppers", "aldrin"]
-- ["foo fighters","bar hoppers","baz aldrin"]
-- >>> zipWith' (*) (replicate 5 2) [1..]
-- [2,4,6,8,10]
-- >>> zipWith' (zipWith' (*)) [[1,2,3],[3,5,6],[2,3,4]] [[3,2,2],[3,4,5],[5,4,3]]
-- [[3,4,6],[9,20,30],[10,12,12]]
zipWith' :: (a -> b -> c) -> [a] -> [b] -> [c]
zipWith' _ [] _              = []
zipWith' _ _ []              = []
zipWith' f (x : xs) (y : ys) = f x y : zipWith' f xs ys

-- | flip'
-- >>> flip' zip [1,2,3,4,5] "hello"
-- [('h',1),('e',2),('l',3),('l',4),('o',5)]
-- >>> zipWith (flip' div) [2,2..] [10,8,6,4,2]
-- [5,4,3,2,1]
flip' :: (a -> b -> c) -> b -> a -> c
flip' f y x = f x y

-- | map'
-- >>> map' (+3) [1,5,3,1,6]
-- [4,8,6,4,9]
-- >>> map' (++ "!") ["BIFF", "BANG", "POW"]
-- ["BIFF!","BANG!","POW!"]
-- >>> map' (replicate 3) [3..6]
-- [[3,3,3],[4,4,4],[5,5,5],[6,6,6]]
-- >>> map' (map (^2)) [[1,2],[3,4,5,6],[7,8]]
-- [[1,4],[9,16,25,36],[49,64]]
-- >>> map' fst [(1,2),(3,5),(6,3),(2,6),(2,5)]
-- [1,3,6,2,2]
map' :: (a -> b) -> [a] -> [b]
map' _ []       = []
map' f (x : xs) = f x : map' f xs

-- | filter'
-- >>> filter' (>3) [1,5,3,2,1,6,4,3,2,1]
-- [5,6,4]
-- >>> filter' (==3) [1,2,3,4,5]
-- [3]
-- >>> filter' even [1..10]
-- [2,4,6,8,10]
-- >>> let notNull x = not (null x) in filter' notNull [[1,2,3],[],[3,4,5],[2,2],[],[],[]]
-- [[1,2,3],[3,4,5],[2,2]]
filter' :: (a -> Bool) -> [a] -> [a]
filter' _ [] = []
filter' f (x : xs)
  | f x = x : filter' f xs
  | otherwise = filter' f xs

-- | quicksort
-- >>> quicksort [5,4,3,2,1]
-- [1,2,3,4,5]
quicksort :: (Ord a) => [a] -> [a]
quicksort [] = []
quicksort (x : xs) =
  let
    smallerSorted = quicksort (filter (<= x) xs)
    biggerSorted = quicksort (filter (> x) xs)
   in
    smallerSorted ++ [x] ++ biggerSorted

-- | largestDivisible
largestDivisible :: (Integral a) => a
largestDivisible = head (filter p [100000, 99999 ..])
  where
    p x = x `mod` 3829 == 0

-- | chain
-- >>> chain 10
-- [10,5,16,8,4,2,1]
-- >>> chain 1
-- [1]
-- >>> chain 30
-- [30,15,46,23,70,35,106,53,160,80,40,20,10,5,16,8,4,2,1]
chain :: (Integral a) => a -> [a]
chain 1 = [1]
chain n
  | even n = n : chain (n `div` 2)
  | odd n = n : chain (n * 3 + 1)

-- | numLongChains
-- >>> numLongChains
-- 66
numLongChains :: Int
numLongChains = length (filter isLong (map chain [1 .. 100]))
  where
    isLong xs = length xs > 15

-- | addThree'
-- >>> addThree' 2 5 7
-- 14
addThree' :: (Num a) => a -> a -> a -> a
addThree' x y z = x + y + z

-- | addThree''
-- >>> addThree'' 2 5 7
-- 14
addThree'' :: (Num a) => a -> a -> a -> a
addThree'' = \x -> \y -> \z -> x + y + z

-- | filp''
-- >>> flip'' zip [1,2,3,4,5] "hello"
-- [('h',1),('e',2),('l',3),('l',4),('o',5)]
flip'' :: (a -> b -> c) -> b -> a -> c
flip'' f = \x y -> f y x

-- | sum'
-- >>> sum' [1,2,3,4]
-- 10
sum' :: (Num a) => [a] -> a
sum' xs = foldl (\acc x -> acc + x) 0 xs

-- | sum''
-- >>> sum'' [1,2,3,4]
-- 10
sum'' :: (Num a) => [a] -> a
sum'' = foldl (+) 0

-- | elem'
elem' :: (Eq a) => a -> [a] -> Bool
elem' y ys =
  foldl
    ( \acc x ->
        if x == y
          then True
          else acc
    )
    False
    ys

-- | map''
map'' :: (a -> b) -> [a] -> [b]
map'' f xs = foldr (\x acc -> f x : acc) [] xs

-- | sum'''
sum''' :: (Num a) => [a] -> a
sum''' xs = foldl (+) 0 xs

-- | oddSquareSum
oddSquareSum :: Integer
oddSquareSum = sum (takeWhile (< 10000) (filter odd (map (^ 2) [1 ..])))

-- | oddSquareSum'
oddSquareSum' :: Integer
oddSquareSum' = sum . takeWhile (< 10000) . filter odd . map (^ 2) $ [1 ..]

-- | oddSquareSum''
oddSquareSum'' :: Integer
oddSquareSum'' =
  let
    oddSquares = filter odd $ map (^ 2) [1 ..]
    belowLimit = takeWhile (< 10000) oddSquares
   in
    sum belowLimit
