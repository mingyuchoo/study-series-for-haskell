module GitPuller.Domain.PullPlan (
  Request (..),
  serialGroups,
)
where

import Data.Map.Strict qualified as Map

data Request = Request
  { path :: FilePath
  , commonDirectory :: FilePath
  }
  deriving (Eq, Show)

serialGroups :: [Request] -> [[FilePath]]
serialGroups requests =
  Map.elems (Map.fromListWith (flip (<>)) (map grouped requests))
 where
  grouped request = (commonDirectory request, [path request])
