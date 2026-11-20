{-# LANGUAGE GADTs #-}

module Main (main) where

import Control.Monad.Writer (Writer, runWriter, tell)
import Data.Functor.Identity (Identity (..))
import GitPuller.Application.Event (Event (..))
import GitPuller.Application.Program (Program (..), Request (..))
import GitPuller.Application.Roles (
  Cast (..),
  Inspector (..),
  Observer (..),
  Surveyor (..),
  Updater (..),
 )
import GitPuller.Application.UpdateWorktrees qualified as UpdateWorktrees
import GitPuller.Domain.Discovery (Entry (..), EntryKind (..))
import GitPuller.Domain.Outcome (Outcome (..), Status (..))
import GitPuller.Domain.Repository (
  Branch (..),
  Inspection (..),
  Operation (..),
  SkipReason (..),
  State (..),
 )
import GitPuller.Domain.Update (Mode (..))
import System.FilePath ((</>))
import Test.Hspec (Spec, describe, hspec, it, shouldBe)

newtype Step = Step String
  deriving (Eq, Show)

step :: Request reply -> Step
step = Step . show

clean :: State
clean = State{branch = Attached, operation = Idle, upstream = True, dirty = False}

commonDirectory :: FilePath
commonDirectory = "/root/main/.git"

reply :: Request reply -> reply
reply (ListDirectory "/root") =
  Right
    [ Entry "/root/linked" Directory
    , Entry "/root/main" Directory
    , Entry "/root/dirty" Directory
    ]
reply (ListDirectory directory) = Right [Entry (directory </> ".git") Regular]
reply (InspectRepository "/root/dirty") = Right (Standalone "/root/dirty/.git" clean{dirty = True})
reply (InspectRepository _) = Right (Standalone commonDirectory clean)
reply (Pull "/root/linked") = Left "diverged"
reply (Pull _) = Right ()
reply (Report _) = ()

execute :: Program result -> Writer [Step] result
execute (Finished result) = pure result
execute (Await request resume) = tell [step request] >> execute (resume (reply request))
execute (Concurrently programs resume) = traverse execute programs >>= execute . resume
execute (Exclusively resource program resume) =
  tell [claimed resource] >> execute program >>= execute . resume

claimed :: FilePath -> Step
claimed resource = Step ("Exclusively " <> show resource)

run :: Mode -> ([Outcome], [Step])
run mode = runWriter (execute (UpdateWorktrees.start mode "/root"))

dirtyOutcome :: Outcome
dirtyOutcome = Outcome "/root/dirty" (Skipped Dirty)

discoverySteps :: [Step]
discoverySteps =
  [ step (Report Scanning)
  , step (ListDirectory "/root")
  , step (ListDirectory "/root/dirty")
  , step (ListDirectory "/root/main")
  , step (ListDirectory "/root/linked")
  , step (Report Discovered)
  , step (Report Discovered)
  , step (Report Discovered)
  , step (Report (Processing 3))
  ]

cast :: Cast Identity
cast =
  Cast
    { surveyor = Surveyor{listDirectory = const (Identity (Left "surveyor"))}
    , inspector = Inspector{inspectRepository = const (Identity (Left "inspector"))}
    , updater = Updater{pull = const (Identity (Left "updater"))}
    , observer = Observer{notify = const (Identity ())}
    }

main :: IO ()
main = hspec $ do
  startSpec
  performSpec

performSpec :: Spec
performSpec = describe "UpdateWorktrees.perform" $
  it "routes each request to the role that answers it" $ do
    UpdateWorktrees.perform cast (ListDirectory "/root") `shouldBe` Identity (Left "surveyor")
    UpdateWorktrees.perform cast (InspectRepository "/root") `shouldBe` Identity (Left "inspector")
    UpdateWorktrees.perform cast (Pull "/root") `shouldBe` Identity (Left "updater")
    UpdateWorktrees.perform cast (Report Scanning) `shouldBe` Identity ()

startSpec :: Spec
startSpec = describe "UpdateWorktrees.start" $ do
  it "plans eligible worktrees without pulling during a dry run" $ do
    let linked = Outcome "/root/linked" Planned
        primary = Outcome "/root/main" Planned
    run DryRun
      `shouldBe` ( [dirtyOutcome, linked, primary]
                 , discoverySteps
                     <> [ step (Report (Inspecting "/root/dirty"))
                        , step (InspectRepository "/root/dirty")
                        , step (Report (Processed dirtyOutcome))
                        , step (Report (Inspecting "/root/linked"))
                        , step (InspectRepository "/root/linked")
                        , step (Report (Processed linked))
                        , step (Report (Inspecting "/root/main"))
                        , step (InspectRepository "/root/main")
                        , step (Report (Processed primary))
                        ]
                 )
  it "pulls each eligible worktree right after its inspection while holding its common directory" $ do
    let linked = Outcome "/root/linked" (Failed "diverged")
        primary = Outcome "/root/main" Updated
    run Apply
      `shouldBe` ( [dirtyOutcome, linked, primary]
                 , discoverySteps
                     <> [ step (Report (Inspecting "/root/dirty"))
                        , step (InspectRepository "/root/dirty")
                        , step (Report (Processed dirtyOutcome))
                        , step (Report (Inspecting "/root/linked"))
                        , step (InspectRepository "/root/linked")
                        , claimed commonDirectory
                        , step (Report (Pulling "/root/linked"))
                        , step (Pull "/root/linked")
                        , step (Report (Processed linked))
                        , step (Report (Inspecting "/root/main"))
                        , step (InspectRepository "/root/main")
                        , claimed commonDirectory
                        , step (Report (Pulling "/root/main"))
                        , step (Pull "/root/main")
                        , step (Report (Processed primary))
                        ]
                 )
