module Chapter02.StartingOut
  where

-- | doubleMe
--
-- >>> doubleMe 0
-- 0
-- >>> doubleMe 1
-- 2
-- >>> doubleMe 2
-- 4
-- >>> doubleMe 100
-- 200
doubleMe :: (Num a) => a -> a
doubleMe x = x + x

-- | doubleUs
-- >>> doubleUs 1 1
-- 4
-- >>> doubleUs 1 2
-- 6
-- >>> doubleUs 2 3
-- 10
doubleUs :: (Num a) => a -> a -> a
doubleUs x y = x * 2 + y * 2

-- | doubleSmallNumber x
-- >>> doubleSmallNumber 1
-- 2
-- >>> doubleSmallNumber 101
-- 101
doubleSmallNumber :: (Ord a, Num a) => a -> a
doubleSmallNumber x =
  if x > 100
    then x
    else x * 2
