module GitPuller.Domain.Repository
  ( Branch (..)
  , Operation (..)
  , State (..)
  , SkipReason (..)
  , Eligibility (..)
  , Inspection (..)
  , classify
  ) where

data Branch = Unborn | Detached | Attached
  deriving (Eq, Show)

data Operation = Idle | Merge | Rebase
  deriving (Eq, Show)

data State = State
  { branch    :: Branch
  , operation :: Operation
  , upstream  :: Bool
  , dirty     :: Bool
  }
  deriving (Eq, Show)

data SkipReason = UnbornBranch | MergeInProgress | RebaseInProgress | DetachedHead | NoUpstream | Dirty | Submodule
  deriving (Eq, Show)

data Eligibility = Eligible
                 | Ineligible SkipReason
  deriving (Eq, Show)

data Inspection = Standalone FilePath State
                | Nested
  deriving (Eq, Show)

classify :: State -> Eligibility
classify state
  | branch state == Unborn = Ineligible UnbornBranch
  | operation state == Merge = Ineligible MergeInProgress
  | operation state == Rebase = Ineligible RebaseInProgress
  | branch state == Detached = Ineligible DetachedHead
  | not (upstream state) = Ineligible NoUpstream
  | dirty state = Ineligible Dirty
  | otherwise = Eligible
