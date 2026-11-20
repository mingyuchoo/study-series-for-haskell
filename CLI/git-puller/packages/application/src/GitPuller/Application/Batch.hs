{-# LANGUAGE GADTs #-}

module GitPuller.Application.Batch (
  Request (..),
  Program (..),
  Batch,
  start,
)
where

import Control.Monad (ap, liftM, replicateM_, (>=>))
import Data.Either (partitionEithers)
import Data.List (sortOn)
import GitPuller.Application.Discovery (Candidate (..), Discovery (..))
import GitPuller.Application.Discovery qualified as Discovery
import GitPuller.Application.Ports (Entry, Event (..))
import GitPuller.Domain.Outcome (Outcome (..), Status (..))
import GitPuller.Domain.PullPlan qualified as PullPlan
import GitPuller.Domain.Repository (Inspection)
import GitPuller.Domain.Update (Mode)
import GitPuller.Domain.Update qualified as Update

data Request reply where
  ListDirectory :: FilePath -> Request (Either String [Entry])
  InspectRepository :: FilePath -> Request (Either String Inspection)
  LocateCommonDirectory :: FilePath -> Request (Either String FilePath)
  Pull :: FilePath -> Request (Either String ())
  Report :: Event -> Request ()

deriving instance Eq (Request reply)

deriving instance Show (Request reply)

data Program result where
  Finished :: result -> Program result
  Await :: Request reply -> (reply -> Program result) -> Program result
  Concurrently :: [Program item] -> ([item] -> Program result) -> Program result

instance Functor Program where
  fmap = liftM

instance Applicative Program where
  pure = Finished
  (<*>) = ap

instance Monad Program where
  Finished result >>= next = next result
  Await request resume >>= next = Await request (resume >=> next)
  Concurrently programs resume >>= next = Concurrently programs (resume >=> next)

type Batch = Program [Outcome]

await :: Request reply -> Program reply
await request = Await request Finished

report :: Event -> Program ()
report = await . Report

concurrently :: [Program item] -> Program [item]
concurrently programs = Concurrently programs Finished

settle :: FilePath -> Status -> Program Outcome
settle location result = do
  let outcome = Outcome{path = location, status = result}
  report (Processed outcome)
  pure outcome

inspect :: Mode -> FilePath -> Program (Either Outcome PullPlan.Request)
inspect mode location = do
  report (Inspecting location)
  inspection <- await (InspectRepository location)
  case Update.afterInspection mode inspection of
    Update.Complete result -> Left <$> settle location result
    Update.Pull -> do
      located <- await (LocateCommonDirectory location)
      case located of
        Left diagnostic -> Left <$> settle location (Failed diagnostic)
        Right commonDirectory -> pure (Right (PullPlan.Request location commonDirectory))

examine :: Mode -> Candidate -> Program (Either Outcome PullPlan.Request)
examine _ (Inaccessible location diagnostic) = Left <$> settle location (Failed diagnostic)
examine mode (Worktree location) = inspect mode location

pull :: FilePath -> Program Outcome
pull location = do
  report (Pulling location)
  result <- await (Pull location)
  settle location (Update.afterPull result)

process :: Mode -> [Candidate] -> Batch
process mode found = do
  report (Processing (length found))
  (settled, requests) <- partitionEithers <$> concurrently (map (examine mode) found)
  pulled <- concurrently (map (traverse pull) (PullPlan.serialGroups requests))
  pure (sortOn path (settled <> concat pulled))

discover :: Mode -> Discovery -> Batch
discover mode discovery = case pending discovery of
  [] -> process mode (Discovery.sorted (candidates discovery))
  directory : remaining -> do
    entries <- await (ListDirectory directory)
    let (next, discovered) = Discovery.afterListing directory discovery{pending = remaining} entries
    replicateM_ discovered (report Discovered)
    discover mode next

start :: Mode -> FilePath -> Batch
start mode root = do
  report Scanning
  discover mode (Discovery.start root)
