module GitPuller.Application.Discovery (
  Candidate (..),
  Discovery (..),
  start,
  sorted,
  afterListing,
)
where

import Data.List (sortOn)
import GitPuller.Application.Ports (Entry (..), EntryKind (..))
import System.FilePath ((</>))

data Candidate = Worktree FilePath | Inaccessible FilePath String
  deriving (Eq, Show)

data Discovery = Discovery
  { pending :: [FilePath]
  , candidates :: [Candidate]
  }
  deriving (Eq, Show)

start :: FilePath -> Discovery
start root = Discovery{pending = [root], candidates = []}

candidatePath :: Candidate -> FilePath
candidatePath (Worktree location) = location
candidatePath (Inaccessible location _) = location

sorted :: [Candidate] -> [Candidate]
sorted = sortOn candidatePath

afterListing :: FilePath -> Discovery -> Either String [Entry] -> (Discovery, Int)
afterListing directory discovery (Left diagnostic) =
  (discovery{candidates = Inaccessible directory diagnostic : candidates discovery}, 0)
afterListing directory discovery (Right entries) =
  foldl' addEntry (discovery, 0) entries
 where
  metadata = directory </> ".git"
  addEntry (state, discovered) entry = case kind entry of
    Unavailable ->
      (state{candidates = Inaccessible (path entry) "cannot inspect path" : candidates state}, discovered)
    Directory
      | path entry == metadata -> worktree state discovered
      | otherwise -> (state{pending = path entry : pending state}, discovered)
    Regular
      | path entry == metadata -> worktree state discovered
      | otherwise -> (state, discovered)
    Other -> (state, discovered)
  worktree state discovered =
    (state{candidates = Worktree directory : candidates state}, discovered + 1)
