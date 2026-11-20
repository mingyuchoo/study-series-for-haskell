module GitPuller.Infrastructure.BatchRunner
  ( run
  ) where

import Control.Concurrent.MVar (newMVar, withMVar)
import GitPuller.Application.Program (Program (..))
import GitPuller.Application.Roles (Cast (..), Observer (..))
import GitPuller.Application.UpdateWorktrees qualified as UpdateWorktrees
import GitPuller.Domain.Outcome (Outcome)
import GitPuller.Domain.Update (Mode)
import GitPuller.Infrastructure.Exclusion qualified as Exclusion
import GitPuller.Infrastructure.WorkerPool qualified as WorkerPool

run :: Cast IO -> Int -> Mode -> FilePath -> IO [Outcome]
run cast jobs mode root = do
  reporting <- newMVar ()
  exclusion <- Exclusion.new
  let serialized = cast {observer = Observer (withMVar reporting . const . notify (observer cast))}
      execute :: Int -> Program result -> IO result
      execute _ (Finished result) = pure result
      execute concurrency (Await request resume) =
        UpdateWorktrees.perform serialized request >>= execute concurrency . resume
      execute concurrency (Concurrently programs resume) =
        WorkerPool.mapConcurrently concurrency (execute 1) programs
          >>= execute concurrency . resume
      execute concurrency (Exclusively resource program resume) =
        Exclusion.within exclusion resource (execute concurrency program)
          >>= execute concurrency . resume
  execute jobs (UpdateWorktrees.start mode root)
