module Chapter11.FunctorsApplicativeFunctorsAndMonoids
  where

import Data.Char
import Data.Kind (Constraint, Type)
import Data.List
import Data.Monoid

myAction :: IO ()
myAction = do
  putStrLn "Enter two numbers one by one."
  a <- (++) <$> getLine <*> getLine
  putStrLn $ "The two lines concatenated turn out to be: " ++ a

type CoolBool :: Type
newtype CoolBool = CoolBool { getCoolBool :: Bool }

helloMe :: CoolBool -> String
helloMe (CoolBool _) = "Hello"

type IntList :: Type
type IntList = [Int]

type CharList :: Type
newtype CharList = CharList { getCharList :: [Char] }

lengthCompare :: String -> String -> Ordering
lengthCompare x y = (length x `compare` length y) `mappend` (x `compare` y)

-- main = do
--     line <- getLine
--     let line' = reverse line
--     putStrLn $ "You said " ++ line' ++ " backwards!"
--     putStrLn $ "Yes, you really said " ++ line' ++ " backwards!"

-- main = do
--     line <- fmap reverse getLine
--     putStrLn $ "You said " ++ line ++ " backwards!"
--     putStrLn $ "Yes, you really said " ++ line ++ " backwards!"

-- import           Data.Char
-- import           Data.List
-- main = do
--     line <- fmap (intersperse '-' . reverse . map toUpper) getLine
--     putStrLn line

-- data CMaybe a = CNothing | CJust Int a deriving (Show)
-- instance Functor CMaybe where
--   fmap f CNothing          = CNothing
--   fmap f (CJust counter x) = CJust (counter+1) (f x)

-- (<$>) :: Functor f => (a -> b) -> f a -> f b
-- f <$> x = fmap f x

-- myAction :: IO String
-- myAction = do
--   a <- getLine
--   b <- getLine
--   return $ a ++ b
--
-- myAction :: IO String
-- myAction = (++) <$> getLine <*> getLine

-- main = do
--   a <- (++) <$> getLine <*> getLine
--   putStrLn $ "The two lines concatenated trun out to be: " ++ a

-- import           Control.Applicative
-- instance Applicative ZipList where
--   pure x = ZipList (repeat x)
--   ZipList fs <*> ZipList xs = ZipList (zipWith (\f x -> f x) fs xs)

-- liftA2 :: (Applicative f) => (a -> b -> c) -> f a -> f b -> f c
-- liftA2 f a b = f <$> a <*> b

-- sequenceA :: (Applicative f) => [f a] -> f [a]
-- sequenceA []     = pure []
-- sequenceA (x:xs) = (:) <$> x <*> sequenceA xs

-- newtype ZipList a = ZipList { getZipList :: [a] }
--
-- data Profession      = Fighter | Archer | Accountant
-- data Race            = Human   | Elf    | Orc        | Goblin
-- data PlayerCharactor = PlayerCharactor Race Profession
--
-- newtype Pair b a = Pair { getPair :: (a,b) }
-- instance Functor (Pair c) where
--   fmap f (Pair (x,y)) = Pair (f x,y)

-- data CoolBool = CoolBool { getCoolBool :: Bool }
-- helloMe :: CoolBool -> String
-- helloMe (CoolBool _) = "hello"
--
-- newtype CoolBool = CoolBool { getCoolBool :: Bool }
-- helloMe :: CoolBool -> String
-- helloMe (CoolBool _) = "hello"

-- type IntList = [Int]
-- newtype CharList = CharList { getCharList :: [Char]

-- import           Data.Monoid
-- lengthCompare :: String -> String -> Ordering
-- lengthCompare x y = (length x `compare` length y) `mappend`
--                     (vowels x `compare` vowels y) `mappend`
--                     (x `compare` y)
--   where vowels = length . filter (`elem` "aeiou")

-- import qualified Data.Foldable as F
-- data Tree a = Empty | Node a (Tree a) (Tree a) deriving (Show, Read, Eq)
----- foldMap :: (Monoid m, Foldable t) => (a -> m) -> t a -> m
-- instance F.Foldable Tree where
--   foldMap f Empty = mempty
--   foldMap f (Node x l r) = F.foldMap f l `mappend`
--                            f x           `mappend`
--                            F.foldMap f r
-- testTree = Node 5
--             (Node 3
--                 (Node 1 Empty Empty)
--                 (Node 6 Empty Empty)
--             )
--             (Node 9
--                 (Node 8 Empty Empty)
--                 (Node 10 Empty Empty)
--             )
