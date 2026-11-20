{-# LANGUAGE GADTs #-}

module Main (main) where

import Control.Monad.Writer (Writer, runWriter, tell)
import GitPuller.Application.Batch (Program (..), Request (..))
import GitPuller.Application.Batch qualified as Batch
import GitPuller.Application.Ports (Entry (..), EntryKind (..), Event (..))
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
import Test.Hspec (describe, hspec, it, shouldBe)

newtype Step = Step String
  deriving (Eq, Show)

step :: Request reply -> Step
step = Step . show

clean :: State
clean = State{branch = Attached, operation = Idle, upstream = True, dirty = False}

reply :: Request reply -> reply
reply (ListDirectory "/root") =
  Right
    [ Entry "/root/linked" Directory
    , Entry "/root/main" Directory
    , Entry "/root/dirty" Directory
    ]
reply (ListDirectory directory) = Right [Entry (directory </> ".git") Regular]
reply (InspectRepository "/root/dirty") = Right (Standalone clean{dirty = True})
reply (InspectRepository _) = Right (Standalone clean)
reply (LocateCommonDirectory _) = Right "/root/main/.git"
reply (Pull "/root/linked") = Left "diverged"
reply (Pull _) = Right ()
reply (Report _) = ()

execute :: Program result -> Writer [Step] result
execute (Finished result) = pure result
execute (Await request resume) = tell [step request] >> execute (resume (reply request))
execute (Concurrently programs resume) = traverse execute programs >>= execute . resume

run :: Mode -> ([Outcome], [Step])
run mode = runWriter (execute (Batch.start mode "/root"))

dirtyOutcome :: Outcome
dirtyOutcome = Outcome "/root/dirty" (Skipped Dirty)

discoverySteps :: [Step]
discoverySteps =
  [ step (Report Scanning)
  , step (ListDirectory "/root")
  , step (ListDirectory "/root/dirty")
  , step (Report Discovered)
  , step (ListDirectory "/root/main")
  , step (Report Discovered)
  , step (ListDirectory "/root/linked")
  , step (Report Discovered)
  , step (Report (Processing 3))
  ]

main :: IO ()
main = hspec $ describe "Batch.start" $ do
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
  it "pulls worktrees sharing a common directory one after another" $ do
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
                        , step (LocateCommonDirectory "/root/linked")
                        , step (Report (Inspecting "/root/main"))
                        , step (InspectRepository "/root/main")
                        , step (LocateCommonDirectory "/root/main")
                        , step (Report (Pulling "/root/linked"))
                        , step (Pull "/root/linked")
                        , step (Report (Processed linked))
                        , step (Report (Pulling "/root/main"))
                        , step (Pull "/root/main")
                        , step (Report (Processed primary))
                        ]
                 )
