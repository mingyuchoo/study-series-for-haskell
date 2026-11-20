module Main (main) where

import Data.Foldable (for_)
import GitPuller.Domain.Outcome (Outcome (..), Status (..), Summary (..))
import GitPuller.Domain.Outcome qualified as Outcome
import GitPuller.Domain.PullPlan qualified as PullPlan
import GitPuller.Domain.Repository (
  Branch (..),
  Eligibility (..),
  Inspection (..),
  Operation (..),
  SkipReason (..),
  State (..),
  classify,
 )
import GitPuller.Domain.Update (Decision (..), Mode (..))
import GitPuller.Domain.Update qualified as Update
import Test.Hspec (Spec, describe, hspec, it, shouldBe)

main :: IO ()
main = hspec $ do
  repositorySpec
  outcomeSpec
  updateSpec
  pullPlanSpec

clean :: State
clean = State{branch = Attached, operation = Idle, upstream = True, dirty = False}

repositorySpec :: Spec
repositorySpec = describe "Repository.classify" $ do
  it "reports an unborn branch before anything else" $
    classify (State Unborn Merge False True) `shouldBe` Ineligible UnbornBranch
  it "reports a merge before a detached head" $
    classify (State Detached Merge False True) `shouldBe` Ineligible MergeInProgress
  it "reports a rebase before a detached head" $
    classify (State Detached Rebase False True) `shouldBe` Ineligible RebaseInProgress
  it "reports a detached head before a missing upstream" $
    classify (State Detached Idle False True) `shouldBe` Ineligible DetachedHead
  it "reports a missing upstream before a dirty worktree" $
    classify (State Attached Idle False True) `shouldBe` Ineligible NoUpstream
  it "reports a dirty worktree" $
    classify (State Attached Idle True True) `shouldBe` Ineligible Dirty
  it "accepts a clean tracking branch" $
    classify clean `shouldBe` Eligible

outcomeSpec :: Spec
outcomeSpec = describe "Outcome" $ do
  let outcomes = [Outcome "a" Planned, Outcome "b" (Failed "error")]
  it "counts outcomes by status" $
    Outcome.summarize outcomes `shouldBe` Summary{updated = 0, planned = 1, skipped = 0, failed = 1}
  it "counts every status" $
    Outcome.summarize [Outcome "a" Updated, Outcome "b" (Skipped Dirty), Outcome "c" Updated]
      `shouldBe` Summary{updated = 2, planned = 0, skipped = 1, failed = 0}
  it "exits with 1 when any outcome failed" $
    Outcome.exitCode outcomes `shouldBe` 1
  it "exits with 0 without failures" $ do
    Outcome.exitCode [] `shouldBe` 0
    Outcome.exitCode [Outcome "a" (Skipped Dirty)] `shouldBe` 0

updateSpec :: Spec
updateSpec = describe "Update" $ do
  let inspect mode = Update.afterInspection mode . Right . Standalone
  it "plans an eligible repository during a dry run" $
    inspect DryRun clean `shouldBe` Complete Planned
  it "pulls an eligible repository when applying" $
    inspect Apply clean `shouldBe` Pull
  for_ [DryRun, Apply] $ \mode -> describe (show mode) $ do
    it "skips an ineligible repository" $
      inspect mode clean{dirty = True} `shouldBe` Complete (Skipped Dirty)
    it "skips a submodule" $
      Update.afterInspection mode (Right Nested) `shouldBe` Complete (Skipped Submodule)
    it "fails when inspection fails" $
      Update.afterInspection mode (Left "inspection failed")
        `shouldBe` Complete (Failed "inspection failed")
  it "marks a successful pull as updated" $
    Update.afterPull (Right ()) `shouldBe` Updated
  it "marks a failed pull as failed" $
    Update.afterPull (Left "pull failed") `shouldBe` Failed "pull failed"

pullPlanSpec :: Spec
pullPlanSpec = describe "PullPlan.serialGroups" $ do
  it "yields no groups without requests" $
    PullPlan.serialGroups [] `shouldBe` []
  it "groups worktrees sharing a common directory in request order" $
    PullPlan.serialGroups
      [ PullPlan.Request "/a" "/shared"
      , PullPlan.Request "/b" "/other"
      , PullPlan.Request "/c" "/shared"
      , PullPlan.Request "/d" "/single"
      ]
      `shouldBe` [["/b"], ["/a", "/c"], ["/d"]]
