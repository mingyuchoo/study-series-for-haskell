module GitPuller.Domain.Update
  ( Mode (..)
  , Phase (..)
  , Signal (..)
  , begin
  , transition
  ) where

import GitPuller.Domain.Discovery (Candidate (..))
import GitPuller.Domain.Outcome (Status (..))
import GitPuller.Domain.Repository
  ( Eligibility (..)
  , Inspection (..)
  , SkipReason (Submodule)
  , classify
  )

data Mode = DryRun | Apply
  deriving (Eq, Show)

data Phase = AwaitingInspection
           | AwaitingPull FilePath
           | Settled Status
  deriving (Eq, Show)

data Signal = Inspected (Either String Inspection)
            | Pulled (Either String ())
  deriving (Eq, Show)

begin :: Candidate -> Phase
begin (Worktree _)                = AwaitingInspection
begin (Inaccessible _ diagnostic) = Settled (Failed diagnostic)

transition :: Mode -> Phase -> Signal -> Phase
transition mode AwaitingInspection (Inspected inspection) = afterInspection mode inspection
transition _ (AwaitingPull _) (Pulled result) =
  Settled (either Failed (const Updated) result)
transition _ phase _ = phase

afterInspection :: Mode -> Either String Inspection -> Phase
afterInspection _ (Left diagnostic) = Settled (Failed diagnostic)
afterInspection _ (Right Nested) = Settled (Skipped Submodule)
afterInspection mode (Right (Standalone commonDirectory state)) =
  case (classify state, mode) of
    (Ineligible reason, _) -> Settled (Skipped reason)
    (Eligible, DryRun)     -> Settled Planned
    (Eligible, Apply)      -> AwaitingPull commonDirectory
