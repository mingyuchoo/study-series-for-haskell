module Chapter04.SyntaxInFunctions
  where

-- | lucky
-- >>> lucky 7
-- "LUCKY NUMBER SEVEN!"
-- >>> lucky 1
-- "Sorry, you're out of luck, pal!"
lucky1 :: (Integral a) => a -> String
lucky1 7 = "LUCKY NUMBER SEVEN!"
lucky1 _ = "Sorry, you're out of luck, pal!"

lucky2 :: (Integral a) => a -> String
lucky2 i
  | i == 7 = "NUMBER SEVEN! YOU ARE LUCKY!"
  | otherwise = "Sorry, you're out of luck, pal!"

lucky3 :: (Integral a) => a -> String
lucky3 i =
  if i == 7
    then "NUMBER SEVEN! YOU ARE LUCKY!"
    else "Sorry, you're out of luck, pal!"

-- | sayMe
-- >>> sayMe 1
-- "One!"
-- >>> sayMe 2
-- "Two!"
-- >>> sayMe 3
-- "Three!"
-- >>> sayMe 4
-- "Four!"
-- >>> sayMe 5
-- "Five!"
-- >>> sayMe 0
-- "Not between 1 and 5"
sayMe :: (Integral a) => a -> String
sayMe 1 = "One!"
sayMe 2 = "Two!"
sayMe 3 = "Three!"
sayMe 4 = "Four!"
sayMe 5 = "Five!"
sayMe _ = "Not between 1 and 5"

-- | factorial
-- >>> factorial 1
-- 1
-- >>> factorial 2
-- 2
-- >>> factorial 3
-- 6
-- >>> factorial 4
-- 24
-- >>> factorial 5
-- 120
-- >>> factorial 50
-- 30414093201713378043612608166064768844377641568960512000000000000
factorial1 :: (Integral a) => a -> a
factorial1 0 = 1
factorial1 n = n * factorial1 (n - 1)

factorial2 :: (Integral a) => a -> a
factorial2 n
  | n <= 0 = error "Factorial is undefined for negative numbers"
  | n == 0 = 1
  | otherwise = n * factorial2 (n - 1)

-- | phoneticCode
-- >>> phoneticCode 'a'
-- "Alpha"
-- >>> phoneticCode 'b'
-- "Bravo"
-- >>> phoneticCode 'c'
-- "Charlie"
-- >>> phoneticCode 'd'
-- "Delta"
phoneticCode :: Char -> String
phoneticCode 'a' = "Alfa"
phoneticCode 'b' = "Bravo"
phoneticCode 'c' = "Charlie"
phoneticCode 'd' = "Delta"
phoneticCode 'e' = "Echo"
phoneticCode 'f' = "Foxtrot"
phoneticCode 'g' = "Golf"
phoneticCode 'h' = "Hotel"
phoneticCode 'i' = "India"
phoneticCode 'j' = "Juliett"
phoneticCode 'k' = "Kilo"
phoneticCode 'l' = "Lima"
phoneticCode 'm' = "Mike"
phoneticCode 'n' = "November"
phoneticCode 'o' = "Oscar"
phoneticCode 'p' = "Papa"
phoneticCode 'q' = "Quebec"
phoneticCode 'r' = "Romeo"
phoneticCode 's' = "Sierra"
phoneticCode 't' = "Tango"
phoneticCode 'u' = "Uniform"
phoneticCode 'v' = "Victor"
phoneticCode 'w' = "Whiskey"
phoneticCode 'x' = "X-ray"
phoneticCode 'y' = "Yankee"
phoneticCode 'z' = "Zulu"
phoneticCode _   = "Others"

-- | addVectors
-- >>> addVectors (1,2) (2,3)
-- (3,5)
addVectors :: forall {a}. (Num a) => (a, a) -> (a, a) -> (a, a)
addVectors (x1, y1) (x2, y2) = (x1 + x2, y1 + y2)

-- | first
-- >>> first (1, 2, 3)
-- 1
-- >>> first ('a', 'b', 'c')
-- 'a'
first :: (a, b, c) -> a
first (x, _, _) = x

-- | second
-- >>> second (1, 2, 3)
-- 2
-- >>> second ([1], [2], [3])
-- [2]
second :: (a, b, c) -> b
second (_, y, _) = y

-- | third
-- >>> third ((1, "a"), [2], 3.0)
-- 3.0
third :: (a, b, c) -> c
third (_, _, z) = z

-- | head'
-- >>> head' [4,5,6]
-- 4
-- >>> head' "Hello"
-- 'H'
head' :: [a] -> a
head' []      = error "Can't call head on an empy list, dummy!"
head' (x : _) = x

-- | tell
-- >>> tell []
-- "The list is empty"
tell :: (Show a) => [a] -> String
tell [] = "The list is empty"
tell (x : []) = "The list has one element: " ++ show x
tell (x : y : []) = "The list has two elements: " ++ show x ++ " and " ++ show y
tell (x : y : _) = "This list is long, The first two elements are: " ++ show x ++ " and " ++ show y

-- | length'
-- >>> length' [1, 2, 3, 4, 5]
-- 5
length' :: (Num b) => [a] -> b
length' []       = 0
length' (_ : xs) = 1 + length' xs

-- | sum'
-- >>> sum' [1,2,3,4,5]
-- 15
sum' :: (Num a) => [a] -> a
sum' []       = 0
sum' (x : xs) = x + sum' xs

-- | capital
-- >>> capital ""
-- "Empty string, whoops!"
-- >>> capital "Dracula"
-- "The first letter of Dracula is D"
capital :: String -> String
capital all@(x : xs) = "The first letter of " ++ all ++ " is " ++ [x]
capital ""           = "Empty string, whoops!"

-- | bmiTell
-- >>> bmiTell 85 1.90
-- "You're supposedly normal. Pffft, I bet you're ugly!"
bmiTell :: (RealFloat a) => a -> a -> String
bmiTell weight height
  | bmi <= skinny = "You're underweight, you emo, you!"
  | bmi <= normal = "You're supposedly normal. Pffft, I bet you're ugly!"
  | bmi <= fat = "You're fat! Lose some weight, fatty!"
  | otherwise = "You're a whale, congratulations!"
  where
    bmi = weight / height ^ 2
    skinny = 18.5
    normal = 25.0
    fat = 30.0

-- | calcBmis
-- >>> calcBmis [(85, 1.90)]
-- [23.545706371191137]
calcBmis :: (RealFloat a) => [(a, a)] -> [a]
calcBmis xs = [bmi w h | (w, h) <- xs]
  where
    bmi weight height = weight / height ^ 2

-- | max'
-- >>> max' 1 2
-- 2
-- >>> max' 2 1
-- 2
-- >>> max' 1 (-1)
-- 1
max' :: (Ord a) => a -> a -> a
max' x y
  | x > y = x
  | otherwise = y

-- | myCompare
-- >>> myCompare 1 1
-- EQ
-- >>> myCompare 1 2
-- LT
-- >>> myCompare 2 1
-- GT
myCompare :: (Ord a) => a -> a -> Ordering
myCompare x y
  | x > y = GT
  | x == y = EQ
  | otherwise = LT

-- | initials
-- >>> initials "Tom" "Brown"
-- "T. B."
initials :: String -> String -> String
initials firstname lastname = [f] ++ ". " ++ [l] ++ "."
  where
    (f : _) = firstname
    (l : _) = lastname

-- | cylinder
-- >>> cylinder 1.1 2.2
-- 22.8079626650619
cylinder :: (Floating a) => a -> a -> a
cylinder r h =
  let
    sideArea = 2 * pi * r * h
    topArea = pi * r ^ 2
   in
    sideArea + 2 * topArea

-- | head''
-- >>> head'' [1,2,3]
-- 1
head'' :: [a] -> a
head'' []      = error "No head for empty lists!"
head'' (x : _) = x

-- | head'''
-- >>> head''' [1,2,3]
-- 1
head''' :: [a] -> a
head''' xs =
  case xs of
    []      -> error "No head for empty list!"
    (x : _) -> x

-- | describeList
-- >>> describeList [1,2,3]
-- "The list is a longer list."
describeList :: [a] -> String
describeList xs =
  "The list is "
    ++ case xs of
      []  -> "empty."
      [x] -> "a singleton list."
      xs  -> "a longer list."

-- | describeList'
-- >>> describeList' [1,2,3]
-- "The list is a longer list."
describeList' :: [a] -> String
describeList' xs = "The list is " ++ what xs
  where
    what []  = "empty."
    what [x] = "a singleton list."
    what xs  = "a longer list."
