{-# LANGUAGE NoImplicitPrelude #-}

module Chapter10.FunctionallySolvingProblems
  where

import Control.Exception (catch)

import Data.Kind (Type)
import Data.List (concat, drop, foldl, head, lines, map, reverse, sum, take, words, (++))

import Prelude
  ( Double (..)
  , IO (..)
  , Int (..)
  , Show (..)
  , String (..)
  , fst
  , getContents
  , log
  , otherwise
  , print
  , putStrLn
  , read
  , return
  , snd
  , undefined
  , ($)
  , (*)
  , (**)
  , (+)
  , (-)
  , (.)
  , (/)
  , (<=)
  )

import System.IO.Error (IOError (..), isEOFError)

doSolveRPN :: IO ()
doSolveRPN = action `catch` handler

action :: IO ()
action = do
  print $ solveRPN "10 4 3 + 2 * -"
  print $ solveRPN "2 3.5 +"
  print $ solveRPN "90 34 12 33 55 66 + * - +"
  print $ solveRPN "90 34 12 33 55 66 + * - + -"
  print $ solveRPN "90 3.8 -"
  return ()

solveRPN :: String -> Double
solveRPN = head . foldl foldingFunction [] . words
  where
    foldingFunction (x0 : x1 : xs) "+" = (x1 + x0) : xs
    foldingFunction (x0 : x1 : xs) "-" = (x1 - x0) : xs
    foldingFunction (x0 : x1 : xs) "*" = (x1 * x0) : xs
    foldingFunction (x0 : x1 : xs) "/" = (x1 / x0) : xs
    foldingFunction (x0 : x1 : xs) "^" = (x1 ** x0) : xs
    foldingFunction (x : xs) "ln"      = log x : xs
    foldingFunction xs "sum"           = [sum xs]
    foldingFunction xs ns              = read ns : xs

handler :: IOError -> IO ()
handler e
  | isEOFError e = putStrLn "EOF Error!"
  | otherwise = putStrLn "Woops, had some trouble!"

-- |
-- Heathrow to London
type Section :: Type -> Type
data Section a = Section
  { getA :: a
  , getB :: a
  , getC :: a
  }
  deriving (Show)

type RoadSystem :: Type
type RoadSystem = [Section Int]

type Label :: Type
data Label = A | B | C
  deriving (Show)

type Path :: Type
type Path = [(Label, Int)]

roadStep :: (Path, Path) -> Section Int -> (Path, Path)
roadStep (pathA, pathB) (Section a b c) =
  let
    timeA = sum (map snd pathA)
    timeB = sum (map snd pathB)

    forwardTimeToA = timeA + a
    crossTimeToA = timeB + b + c

    forwardTimeToB = timeB + b
    crossTimeToB = timeA + a + c

    newPathToA =
      if forwardTimeToA <= crossTimeToA
        then (A, a) : pathA
        else (C, c) : (B, b) : pathB
    newPathToB =
      if forwardTimeToB <= crossTimeToB
        then (B, b) : pathB
        else (C, c) : (A, a) : pathA
   in
    (newPathToA, newPathToB)

optimalPath :: RoadSystem -> Path
optimalPath roadSystem =
  let
    (bestAPath, bestBPath) = foldl roadStep ([], []) roadSystem
   in
    if sum (map snd bestAPath) <= sum (map snd bestBPath)
      then reverse bestAPath
      else reverse bestBPath

groupOf :: Int -> [a] -> [[a]]
groupOf 0 _  = undefined
groupOf _ [] = []
groupOf n xs = take n xs : groupOf n (drop n xs)

-- | execution
findOptimalPath :: IO ()
findOptimalPath = do
  let path = optimalPath heathrowToLondon
      pathString = concat $ map (show . fst) path
      pathTime = sum $ map snd path
  putStrLn $ "The best path to take is: " ++ pathString
  putStrLn $ "Time taken: " ++ show pathTime

-- findOptimalPath :: IO ()
-- findOptimalPath = do
--     contents <- getContents
--     let
--         threes = groupOf 3 (map read $ lines contents)
--         roadSystem = map (\[a,b,c] -> Section a b c) threes
--         path = optimalPath roadSystem
--         pathString = concat $ map (show . fst) path
--         pathTime = sum $ map snd path
--     putStrLn $ "The best path to take is: " ++ pathString
--     putStrLn $ "Time taken: " ++ show pathTime

-- | heathrowToLondon
heathrowToLondon :: RoadSystem
heathrowToLondon =
  [ Section 50 10 30
  , Section 5 90 20
  , Section 40 2 25
  , Section 10 8 0
  ]
