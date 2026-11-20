module GitPuller.Domain.Update (
  Mode (..),
  Decision (..),
  afterInspection,
  afterPull,
)
where

import GitPuller.Domain.Outcome (Status (..))
import GitPuller.Domain.Repository (
  Eligibility (..),
  Inspection (..),
  SkipReason (Submodule),
  classify,
 )

data Mode = DryRun | Apply
  deriving (Eq, Show)

data Decision = Complete Status | Pull
  deriving (Eq, Show)

afterInspection :: Mode -> Either String Inspection -> Decision
afterInspection _ (Left diagnostic) = Complete (Failed diagnostic)
afterInspection _ (Right Nested) = Complete (Skipped Submodule)
afterInspection mode (Right (Standalone state)) =
  case (classify state, mode) of
    (Ineligible reason, _) -> Complete (Skipped reason)
    (Eligible, DryRun) -> Complete Planned
    (Eligible, Apply) -> Pull

afterPull :: Either String () -> Status
afterPull = either Failed (const Updated)
