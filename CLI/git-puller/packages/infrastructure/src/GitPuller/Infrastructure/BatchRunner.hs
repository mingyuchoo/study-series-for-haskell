{-# LANGUAGE GADTs #-}

module GitPuller.Infrastructure.BatchRunner (
  run,
)
where

import Control.Concurrent.MVar (newMVar, withMVar)
import GitPuller.Application.Batch (Program (..), Request (..))
import GitPuller.Application.Batch qualified as Batch
import GitPuller.Application.Ports (Ports)
import GitPuller.Application.Ports qualified as Ports
import GitPuller.Domain.Outcome (Outcome)
import GitPuller.Domain.Update (Mode)
import GitPuller.Infrastructure.WorkerPool qualified as WorkerPool

run :: Ports IO -> Int -> Mode -> FilePath -> IO [Outcome]
run ports jobs mode root = do
  reporting <- newMVar ()
  let perform :: Request reply -> IO reply
      perform (ListDirectory location) = Ports.listDirectory ports location
      perform (InspectRepository location) = Ports.inspectRepository ports location
      perform (LocateCommonDirectory location) = Ports.locateCommonDirectory ports location
      perform (Pull location) = Ports.pull ports location
      perform (Report event) = withMVar reporting (const (Ports.report ports event))
      execute :: Int -> Program result -> IO result
      execute _ (Finished result) = pure result
      execute concurrency (Await request resume) = perform request >>= execute concurrency . resume
      execute concurrency (Concurrently programs resume) =
        WorkerPool.mapConcurrently concurrency (execute 1) programs >>= execute concurrency . resume
  execute jobs (Batch.start mode root)
