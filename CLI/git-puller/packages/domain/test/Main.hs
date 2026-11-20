module Main
  ( main
  ) where

import Data.Foldable (for_, toList)
import Data.List.NonEmpty (NonEmpty (..))
import GitPuller.Domain.Discovery
  ( Candidate (..)
  , Discovery (..)
  , Entry (..)
  , EntryKind (..)
  , Listing (..)
  )
import GitPuller.Domain.Discovery qualified as Discovery
import GitPuller.Domain.Outcome (Outcome (..), Status (..), Summary (..))
import GitPuller.Domain.Outcome qualified as Outcome
import GitPuller.Domain.Repository
  ( Branch (..)
  , Eligibility (..)
  , Inspection (..)
  , Operation (..)
  , SkipReason (..)
  , State (..)
  , classify
  )
import GitPuller.Domain.Update (Mode (..), Phase (..), Signal (..))
import GitPuller.Domain.Update qualified as Update
import Test.Hspec (Spec, describe, hspec, it, shouldBe)

main :: IO ()
main = hspec $ do
  repositorySpec
  discoverySpec
  outcomeSpec
  updateSpec

clean :: State
clean = State {branch = Attached, operation = Idle, upstream = True, dirty = False}

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
    Outcome.summarize outcomes
      `shouldBe` Summary {updated = 0, planned = 1, skipped = 0, failed = 1}
  it "counts every status" $
    Outcome.summarize [Outcome "a" Updated, Outcome "b" (Skipped Dirty), Outcome "c" Updated]
      `shouldBe` Summary {updated = 2, planned = 0, skipped = 1, failed = 0}
  it "exits with 1 when any outcome failed" $
    Outcome.exitCode outcomes `shouldBe` 1
  it "exits with 0 without failures" $ do
    Outcome.exitCode [] `shouldBe` 0
    Outcome.exitCode [Outcome "a" (Skipped Dirty)] `shouldBe` 0

updateSpec :: Spec
updateSpec = describe "Update" $ do
  let inspected = Inspected . Right . Standalone "/a/.git"
  it "begins a worktree awaiting inspection" $
    Update.begin (Worktree "/a") `shouldBe` AwaitingInspection
  it "begins an inaccessible directory as settled with its failure" $
    Update.begin (Inaccessible "/a" "blocked") `shouldBe` Settled (Failed "blocked")
  it "plans an eligible repository during a dry run" $
    Update.transition DryRun AwaitingInspection (inspected clean) `shouldBe` Settled Planned
  it "awaits a pull of an eligible repository under its common directory when applying" $
    Update.transition Apply AwaitingInspection (inspected clean)
      `shouldBe` AwaitingPull "/a/.git"
  for_ [DryRun, Apply] $ \mode -> describe (show mode) $ do
    let transition = Update.transition mode
    it "skips an ineligible repository" $
      transition AwaitingInspection (inspected clean {dirty = True})
        `shouldBe` Settled (Skipped Dirty)
    it "skips a submodule" $
      transition AwaitingInspection (Inspected (Right Nested))
        `shouldBe` Settled (Skipped Submodule)
    it "fails when inspection fails" $
      transition AwaitingInspection (Inspected (Left "inspection failed"))
        `shouldBe` Settled (Failed "inspection failed")
    it "marks a successful pull as updated" $
      transition (AwaitingPull "/a/.git") (Pulled (Right ())) `shouldBe` Settled Updated
    it "marks a failed pull as failed" $
      transition (AwaitingPull "/a/.git") (Pulled (Left "pull failed"))
        `shouldBe` Settled (Failed "pull failed")
    it "ignores a signal the current phase does not await" $ do
      transition AwaitingInspection (Pulled (Right ())) `shouldBe` AwaitingInspection
      transition (AwaitingPull "/a/.git") (inspected clean) `shouldBe` AwaitingPull "/a/.git"
      transition (Settled Planned) (Pulled (Left "late")) `shouldBe` Settled Planned

discoverySpec :: Spec
discoverySpec = describe "Discovery" $ do
  let rootListing = Discovery.afterListings (Discovery.start "/root") . pure . Listing "/root"
      listed listing directory = Listing directory (listing directory)
      explore listing discovery = case discovery of
        Complete found -> (found, [], 0 :: Int)
        Exploring directories _ ->
          let wave = toList directories
              (next, discovered) = Discovery.afterListings discovery (map (listed listing) wave)
              (found, waves, total) = explore listing next
           in (found, wave : waves, discovered + total)
  it "starts by exploring the root" $
    Discovery.start "/root" `shouldBe` Exploring ("/root" :| []) []
  it "completes without candidates when the root holds no worktree" $
    rootListing (Right [Entry "/root/file" Regular]) `shouldBe` (Complete [], 0)
  it "records the root as inaccessible when it cannot be listed" $
    rootListing (Left "blocked") `shouldBe` (Complete [Inaccessible "/root" "blocked"], 0)
  it "recognizes a directory or a file named .git as worktree metadata" $ do
    rootListing (Right [Entry "/root/.git" Directory])
      `shouldBe` (Complete [Worktree "/root"], 1)
    rootListing (Right [Entry "/root/.git" Regular])
      `shouldBe` (Complete [Worktree "/root"], 1)
  it "leaves a completed discovery unchanged" $
    Discovery.afterListings
      (Complete [Worktree "/root"])
      [Listing "/root" (Right [Entry "/root/.git" Directory])]
      `shouldBe` (Complete [Worktree "/root"], 0)
  it "explores every directory of a level in one wave and yields candidates in path order" $ do
    let listing "/root" =
          Right
            [ Entry "/root/z" Directory
            , Entry "/root/link" Other
            , Entry "/root/gone" Unavailable
            , Entry "/root/a" Directory
            , Entry "/root/.git" Directory
            ]
        listing "/root/a" = Left "blocked"
        listing "/root/z" = Right [Entry "/root/z/.git" Regular, Entry "/root/z/deep" Directory]
        listing directory = Right [Entry (directory <> "/.git") Regular]
    explore listing (Discovery.start "/root")
      `shouldBe` (
                   [ Worktree "/root"
                   , Inaccessible "/root/a" "blocked"
                   , Inaccessible "/root/gone" "cannot inspect path"
                   , Worktree "/root/z"
                   , Worktree "/root/z/deep"
                   ]
                 , [["/root"], ["/root/a", "/root/z"], ["/root/z/deep"]]
                 , 3
                 )
