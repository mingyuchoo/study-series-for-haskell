module GitPuller.Cli.Arguments (
  Options (..),
  Command (..),
  defaultJobs,
  usage,
  parse,
)
where

import Data.Char (isDigit)
import Data.Maybe (fromMaybe, isNothing)
import GitPuller.Domain.Update (Mode (..))
import Text.Read (readMaybe)

data Options = Options
  { path :: FilePath
  , mode :: Mode
  , verbose :: Bool
  , jobs :: Int
  }
  deriving (Eq, Show)

data Command = Help | Run Options
  deriving (Eq, Show)

data Flags = Flags
  { requestedMode :: Maybe Mode
  , requestedVerbose :: Bool
  , requestedJobs :: Maybe Int
  }

defaultJobs :: Int
defaultJobs = 16

usage :: String
usage = "Usage: git-puller [--dry-run] [--verbose] [--jobs <count>] <path> | git-puller --help"

parseJobs :: String -> Maybe Int
parseJobs text
  | null text || not (all isDigit text) = Nothing
  | otherwise = readMaybe text >>= bounded
 where
  bounded :: Integer -> Maybe Int
  bounded count
    | count >= 1 && count <= toInteger (maxBound :: Int) = Just (fromInteger count)
    | otherwise = Nothing

parse :: [String] -> Either String Command
parse ["--help"] = Right Help
parse arguments = Run <$> parseOptions (Flags Nothing False Nothing) arguments

parseOptions :: Flags -> [String] -> Either String Options
parseOptions flags arguments = case arguments of
  "--dry-run" : rest
    | isNothing (requestedMode flags) -> parseOptions flags{requestedMode = Just DryRun} rest
  "--verbose" : rest
    | not (requestedVerbose flags) -> parseOptions flags{requestedVerbose = True} rest
  "--jobs" : count : rest
    | isNothing (requestedJobs flags) -> case parseJobs count of
        Nothing -> Left "expected a positive job count"
        requested -> parseOptions flags{requestedJobs = requested} rest
  [location@(first : _)]
    | first /= '-' -> Right (options location)
  ["--", location@(_ : _)] -> Right (options location)
  _ -> Left "expected one path"
 where
  options location =
    Options
      { path = location
      , mode = fromMaybe Apply (requestedMode flags)
      , verbose = requestedVerbose flags
      , jobs = fromMaybe defaultJobs (requestedJobs flags)
      }
