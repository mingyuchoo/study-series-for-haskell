module Chapter12.AFistfulOfMonads
  where

import Control.Monad

import Data.Kind (Constraint, Type)

chapter12 :: IO ()
chapter12 = do
  print $ (*) <$> Just 2 <*> Just 8
  print $ (++) <$> Just "klingon" <*> Nothing
  print $ (-) <$> [3, 4] <*> [1, 2, 3]

  print $ fmap (++ "!") (Just "wisdom")
  print $ fmap (++ "!") Nothing

  print $ Just (+ 3) <*> Just 3

  print $ max <$> Just 3 <*> Just 6
  print $ max <$> Just 3 <*> Nothing

  print $ (\x -> Just (x + 1)) 1
  print $ (\x -> Just (x + 1)) 100

  print $ Just 3 `applyMaybe` \x -> Just (x + 1)
  print $ Just "smile" `applyMaybe` \x -> Just (x ++ " :)")
  print $ Nothing `applyMaybe` \x -> Just (x + 1)
  print $ Nothing `applyMaybe` \x -> Just (x ++ " :)")
  print $ Just 3 `applyMaybe` \x -> if x > 2 then Just x else Nothing
  print $ Just 1 `applyMaybe` \x -> if x > 2 then Just x else Nothing

  print $ do return "WHAT" :: Maybe String
  print $ Just 9 >>= \x -> return (x * 10)
  print $ Nothing >>= \x -> return (x * 10)

  print $ landLeft 2 (0, 0)
  print $ landRight 1 (0, 0)
  print $ landLeft (-1) (0, 0)
  print $ landLeft 2 (landRight 1 (landLeft 1 (0, 0)))

  print $ 100 -: (* 3)
  print $ True -: not
  print $ (0, 0) -: landLeft 2
  print $ (0, 0) -: landLeft 1 -: landRight 1 -: landLeft 2

  print $ landLeft 10 (0, 3)
  print $ (0, 0) -: landLeft 1 -: landRight 4 -: landLeft (-1) -: landRight (-2)

  print $ landLeft' 2 (0, 0)
  print $ landLeft' 10 (0, 3)
  print $ landRight' 1 (0, 0) >>= landLeft' 2
  print $ return (0, 0) >>= landRight' 2 >>= landLeft' 2 >>= landRight' 2
  print $
    return (0, 0) >>= landLeft' 1 >>= landRight' 4 >>= landLeft' (-1) >>= landRight' (-2)

  print $ return (0, 0) >>= landLeft' 1 >>= banana >>= landRight' 1
  print $ Nothing >> Just 3
  print $ Just 3 >> Just 4
  print $ return (0, 0) >>= landLeft' 1 >> Nothing >>= landRight' 1

  print $ Just 3 >>= (\x -> Just (show x ++ "!"))
  print $ Just 3 >>= (\x -> Just "!" >>= (\y -> Just (show x ++ y)))

  print $ Just 9 >>= (\x -> Just (x > 8))
  print $ marySue

  print $ routine
  print $ routine'

  print $ justH
  print $ wopwop

  print $ [3, 4, 5] >>= \x -> [x, -x]
  print $ [] >>= \x -> ["bad", "mad", "rad"]
  print $ [1, 2] >>= \n -> ['a', 'b'] >>= \ch -> return (n, ch)
  print $ listOfTuples
  print $ [(n, ch) | n <- [1, 2], ch <- ['a', 'b']]
  print $ [x | x <- [1 .. 50], '7' `elem` show x]

  -- import Control.Monad
  print $ do guard (5 > 2) :: Maybe ()
  print $ do guard (1 > 2) :: Maybe ()
  print $ do guard (5 > 2) :: [()]
  print $ do guard (1 > 2) :: [()]
  print $ do [1 .. 50] >>= (\x -> guard ('7' `elem` show x) >> return x)
  print $ do guard (5 > 2) >> return "cool" :: [String]
  print $ do guard (1 > 2) >> return "cool" :: [String]
  print sevensOnly

  -- Left identity
  print $ return 3 >>= (\x -> Just (x + 100000))
  print $ (\x -> Just (x + 100000)) 3

  print $ return "WoM" >>= (\x -> [x, x, x])
  print $ (\x -> [x, x, x]) "WoM"

  -- Right identity
  print $ Just "move on up" >>= (\x -> return x)
  print $ [1, 2, 3, 4] >>= (\x -> return x)
  putStrLn "Wah!" >>= (\x -> return x)

  return ()

applyMaybe :: Maybe a -> (a -> Maybe b) -> Maybe b
applyMaybe Nothing f  = Nothing
applyMaybe (Just x) f = f x

type Birds :: Type
type Birds = Int

type Pole :: Type
type Pole = (Birds, Birds)

landLeft :: Birds -> Pole -> Pole
landLeft n (left, right) = (left + n, right)

landRight :: Birds -> Pole -> Pole
landRight n (left, right) = (left, right + 1)

-- | (-:) :: t1 -> (t1 -> t2) -> t2
x -: f = f x

landLeft' :: Birds -> Pole -> Maybe Pole
landLeft' n (left, right)
  | abs (left + n - right) < 4 = Just (left + n, right)
  | otherwise = Nothing

landRight' :: Birds -> Pole -> Maybe Pole
landRight' n (left, right)
  | abs (left - (right + n)) < 4 = Just (left, right + n)
  | otherwise = Nothing

banana :: Pole -> Maybe Pole
banana _ = Nothing

foo :: Maybe String
foo =
  Just 3
    >>= ( \x ->
            Just "!"
              >>= ( \y ->
                      Just (show x ++ y)
                  )
        )

foo' :: Maybe String
foo' = do
  x <- Just 3
  y <- Just "!"
  Just (show x ++ y)

marySue :: Maybe Bool
marySue = do
  x <- Just 9
  Just (x > 8)

routine :: Maybe Pole
routine = do
  start <- return (0, 0)
  first <- landLeft' 2 start
  second <- landRight' 2 first
  landLeft' 1 second

routine' :: Maybe Pole
routine' = do
  start <- return (0, 0)
  first <- landLeft' 2 start
  Nothing
  second <- landRight' 2 first
  landLeft' 1 second

justH :: Maybe Char
justH = do
  (x : xs) <- Just "hello"
  return x

wopwop :: Maybe Char
wopwop = do
  (x : xs) <- Just ""
  return x

listOfTuples :: [(Int, Char)]
listOfTuples = do
  n <- [1, 2]
  ch <- ['a', 'b']
  return (n, ch)

sevensOnly :: [Int]
sevensOnly = do
  x <- [1 .. 50]
  guard ('7' `elem` show x)
  return x

type KnightPos :: Type
type KnightPos = (Int, Int)

moveKnight :: KnightPos -> [KnightPos]
moveKnight (c, r) = do
  (c', r') <-
    [ (c + 2, r - 1)
    , (c + 2, r + 1)
    , (c - 2, r - 1)
    , (c - 2, r + 1)
    , (c + 1, r - 2)
    , (c + 1, r + 2)
    , (c - 1, r - 2)
    , (c - 1, r + 2)
    ]
  guard (c' `elem` [1 .. 8] && r' `elem` [1 .. 8])
  return (c', r')

moveKnight' :: KnightPos -> [KnightPos]
moveKnight' (c, r) =
  filter
    onBoard
    [ (c + 2, r - 1)
    , (c + 2, r + 1)
    , (c - 2, r - 1)
    , (c - 2, r + 1)
    , (c + 1, r - 2)
    , (c + 1, r + 2)
    , (c - 1, r - 2)
    , (c - 1, r + 2)
    ]
  where
    onBoard (c, r) = c `elem` [1 .. 8] && r `elem` [1 .. 8]

in3 :: KnightPos -> [KnightPos]
in3 start = do
  first <- moveKnight start
  second <- moveKnight first
  moveKnight second

in3' start = return start >>= moveKnight >>= moveKnight >>= moveKnight

canReachIn3 :: KnightPos -> KnightPos -> Bool
canReachIn3 start end = end `elem` in3 start

(<=<) :: (Monad m) => (b -> m c) -> (a -> m b) -> (a -> m c)
f <=< g = (\x -> g x >>= f)
