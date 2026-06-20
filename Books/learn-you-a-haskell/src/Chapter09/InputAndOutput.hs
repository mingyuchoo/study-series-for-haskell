module Chapter09.InputAndOutput
  where

import Control.Exception (catch)
import Control.Monad (forM, forever, when)

import Data.Bool (Bool (..), not)
import Data.ByteString qualified as S
import Data.ByteString.Lazy qualified as B
import Data.Char
import Data.Eq (Eq (..))
import Data.List (delete, null, take)

import System.Directory (copyFile, removeFile, renameFile)
import System.Environment (getArgs)
import System.IO
  ( Handle (..)
  , IO (..)
  , IOMode (..)
  , getLine
  , hClose
  , hGetContents
  , hPutStr
  , openFile
  , openTempFile
  , print
  , putStrLn
  , readFile
  )
import System.IO.Error
  ( IOError (..)
  , ioError
  , ioeGetFileName
  , isDoesNotExistError
  , isFullError
  , isIllegalOperation
  )
import System.Random
  ( Random
  , RandomGen
  , StdGen (..)
  , getStdGen
  , mkStdGen
  , random
  , randomR
  , randoms
  )

-- | evaludate functions
someFunc :: IO ()
someFunc = do
  putStrLn "----------------------------"

-- | make factorial number
factorial :: Int -> Int
factorial n
  | n == 0 = 0
  | n == 1 = 1
  | otherwise = n * factorial (n - 1)

-- | use case of `getLine`
askName :: IO ()
askName = do
  _ <- putStrLn "What's your first name?"
  firstName <- getLine
  _ <- putStrLn "What's your last name?"
  lastName <- getLine
  let bigFirstName = map toUpper firstName
      bigLastName = map toUpper lastName
  _ <-
    putStrLn $
      "Hey "
        ++ bigFirstName
        ++ " "
        ++ bigLastName
        ++ ", how are you?"
  return ()

makeReverse :: IO ()
makeReverse = do
  line <- getLine
  if null line
    then return ()
    else
      (putStrLn $ reverseWords line)
        >> makeReverse
        >> return ()

reverseWords :: String -> String
reverseWords = unwords . map reverse . words

-- | use cases of `return`
assertReturn :: IO ()
assertReturn = do
  _ <- return ()
  a <- return "HAHAHA" -- :: Monad m => m [Char]
  line <- getLine
  b <- return "BLAH BLAH BLAH" -- :: Monad m => m [Char]
  _ <- return 4
  _ <- putStrLn $ a ++ " " ++ b
  _ <- putStrLn line
  let c = "hell"
      d = "yeah"
  _ <- putStrLn $ c ++ " " ++ d
  return ()

-- | example of `when`
exampleWhen :: IO ()
exampleWhen = do
  input <- getLine
  -- when expression
  when (input == "SWORDFISH") $ do
    _ <- putStrLn input
    return ()
  -- if expression
  if (input == "SWORDFISH")
    then putStrLn input
    else return ()

-- | example of `sequence`
--  sequence :: (Traversable t, Monad m) => t (m a) -> m (t a)
exampleSequence :: IO ()
exampleSequence = do
  -- sequence expression
  rs <- sequence [getLine, getLine, getLine]
  print rs
  -- bind statement
  a <- getLine
  b <- getLine
  c <- getLine
  print [a, b, c]

-- | example of `mapM` and `mapM_`
exampleMapM :: IO ()
exampleMapM = do
  _ <- sequence $ map print [1, 2, 3, 4, 5]
  _ <- mapM print [1, 2, 3, 4, 5]
  _ <- mapM_ print [1, 2, 3, 4, 5]
  return ()

-- | example of `forever`
exampleForever :: IO ()
exampleForever = do
  forever $ do
    putStr "Give me some input: "
    input <- getLine
    putStrLn $ map toUpper input

-- | example of `forM`
exampleForM :: IO ()
exampleForM = do
  colors <-
    forM
      [1, 2, 3, 4]
      ( \a -> do
          putStrLn $ "Which color do you associate with the number " ++ show a ++ "?"
          color <- getLine
          return color
      )
  putStrLn "The colors that you associate with 1, 2, 3, and 4 are: "
  mapM putStrLn colors
  return ()

-- | withFile
withFile' :: FilePath -> IOMode -> (Handle -> IO a) -> IO a
withFile' path mode f = do
  handle <- openFile path mode
  result <- f handle
  hClose handle
  return result

-- | todoList
todoList = do
  (command : args) <- getArgs
  let (Just action) = lookup command dispatch
  action args

dispatch :: [(String, [String] -> IO ())]
dispatch = [("add", add), ("view", view), ("remove", remove)]

add :: [String] -> IO ()
add [fileName, todoItem] = appendFile fileName (todoItem ++ "\n")

view :: [String] -> IO ()
view [fileName] = do
  contents <- readFile fileName
  let todoTasks = lines contents
      numberedTasks =
        zipWith (\n line -> show n ++ " - " ++ line) [0 ..] todoTasks
  putStr $ unlines numberedTasks

remove :: [String] -> IO ()
remove [fileName, numberString] = do
  handle <- openFile fileName ReadMode
  (tempName, tempHandle) <- openTempFile "." "temp"
  contents <- hGetContents handle
  let number = read numberString
      todoTasks = lines contents
      newTodoItems = delete (todoTasks !! number) todoTasks
  hPutStr tempHandle $ unlines newTodoItems
  hClose handle
  hClose tempHandle
  removeFile fileName
  renameFile tempName fileName

-- | random
-- |
threeCoins :: StdGen -> (Bool, Bool, Bool)
threeCoins gen =
  let (firstCoin, newGen) = random gen
      (secondCoin, newGen') = random newGen
      (thirdCoin, newGen'') = random newGen'
   in (firstCoin, secondCoin, thirdCoin)

randoms' :: (RandomGen g, Random a) => g -> [a]
randoms' gen =
  let (value, newGen) = random gen
   in value : randoms' newGen

finiteRandoms
  :: forall g a n
   . (RandomGen g, Random a, Eq n, Num n)
  => n -> g -> ([a], g)
finiteRandoms 0 gen = ([], gen)
finiteRandoms n gen =
  let (value, newGen) = random gen
      (restOfList, finalGen) = finiteRandoms (n - 1) newGen
   in (value : restOfList, finalGen)

askForNumber :: StdGen -> IO ()
askForNumber gen = do
  let (randomNumber, newGen) = randomR (1, 10) gen :: (Int, StdGen)
  putStrLn "Which number in the range from 1 to 10 am I thining of? "
  numberString <- getLine
  when (not $ null numberString) $ do
    let number = read numberString
    if randomNumber == number
      then putStrLn "You are correct!"
      else putStrLn $ "Sorry, it was " ++ show randomNumber
    askForNumber newGen

-- | Bytestrings
doCopyFile = do
  (fileName1 : fileName2 : _) <- getArgs
  copyFile fileName1 fileName2

copyFile' :: FilePath -> FilePath -> IO ()
copyFile' source dest = do
  contents <- B.readFile source
  B.writeFile dest contents

-- | Exception
doCatchException :: IO ()
doCatchException = catch action handler

action :: IO ()
action = do
  (fileName : _) <- getArgs
  contents <- readFile fileName
  putStrLn $ "The file has " ++ show (length (lines contents)) ++ " lines!"

handler :: IOError -> IO ()
handler e
  | isDoesNotExistError e =
      case ioeGetFileName e of
        Just path -> putStrLn $ "Whoops, File does not exist at: " ++ path
        Nothing   -> putStrLn "Whoops! File does not exist at unknown location!"
  | isFullError e = putStrLn "free some space"
  | isIllegalOperation e = putStrLn "notify cops!"
  | otherwise = ioError e
