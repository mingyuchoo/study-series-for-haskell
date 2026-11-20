module GitPuller.Infrastructure.GitOutput (
  Layout (..),
  Snapshot (..),
  layoutArguments,
  parseLayout,
  snapshotArguments,
  parseSnapshot,
)
where

import Data.List (intercalate, isPrefixOf)
import GitPuller.Domain.Repository (Branch (..))

data Layout = Layout
  { toplevel :: FilePath
  , gitDirectory :: FilePath
  , commonDirectory :: FilePath
  , superproject :: FilePath
  }
  deriving (Eq, Show)

data Snapshot = Snapshot
  { branch :: Branch
  , tracking :: Bool
  , changed :: Bool
  }
  deriving (Eq, Show)

fieldSeparator :: String
fieldSeparator = "--git-puller-field"

layoutArguments :: [String]
layoutArguments =
  [ "rev-parse"
  , "--show-toplevel"
  , fieldSeparator
  , "--absolute-git-dir"
  , fieldSeparator
  , "--path-format=absolute"
  , "--git-common-dir"
  , fieldSeparator
  , "--show-superproject-working-tree"
  ]

fields :: [String] -> [String]
fields outputLines = case break (== fieldSeparator) outputLines of
  (field, []) -> [intercalate "\n" field]
  (field, _ : remaining) -> intercalate "\n" field : fields remaining

parseLayout :: String -> Maybe Layout
parseLayout text = case fields (lines text) of
  [root, metadata, common, parent] ->
    Just
      Layout
        { toplevel = root
        , gitDirectory = metadata
        , commonDirectory = common
        , superproject = parent
        }
  _ -> Nothing

snapshotArguments :: [String]
snapshotArguments =
  [ "status"
  , "--porcelain=v2"
  , "--branch"
  , "--no-ahead-behind"
  , "--untracked-files=normal"
  , "--ignore-submodules=none"
  ]

parseSnapshot :: String -> Snapshot
parseSnapshot text =
  Snapshot
    { branch = current
    , tracking = any ("# branch.ab " `isPrefixOf`) headers
    , changed = not (null changes)
    }
 where
  (headers, changes) = span ("# " `isPrefixOf`) (lines text)
  current
    | "# branch.oid (initial)" `elem` headers = Unborn
    | "# branch.head (detached)" `elem` headers = Detached
    | otherwise = Attached
