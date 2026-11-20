module GitPuller.Domain.Outcome
  ( Status (..)
  , Outcome (..)
  , Summary (..)
  , summarize
  , exitCode
  ) where

import GitPuller.Domain.Repository (SkipReason)

data Status = Updated
            | Planned
            | Skipped SkipReason
            | Failed String
  deriving (Eq, Show)

data Outcome = Outcome
  { path   :: FilePath
  , status :: Status
  }
  deriving (Eq, Show)

data Summary = Summary
  { updated :: Int
  , planned :: Int
  , skipped :: Int
  , failed  :: Int
  }
  deriving (Eq, Show)

summarize :: [Outcome] -> Summary
summarize = foldl' count (Summary 0 0 0 0)
  where
    count summary outcome = case status outcome of
      Updated   -> summary {updated = updated summary + 1}
      Planned   -> summary {planned = planned summary + 1}
      Skipped _ -> summary {skipped = skipped summary + 1}
      Failed _  -> summary {failed = failed summary + 1}

exitCode :: [Outcome] -> Int
exitCode outcomes
  | any (isFailure . status) outcomes = 1
  | otherwise = 0
  where
    isFailure (Failed _) = True
    isFailure _          = False
