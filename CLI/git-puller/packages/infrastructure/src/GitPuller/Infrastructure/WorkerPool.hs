module GitPuller.Infrastructure.WorkerPool (
  mapConcurrently,
)
where

import Control.Concurrent (forkIO)
import Control.Concurrent.MVar (MVar, modifyMVar, newEmptyMVar, newMVar, putMVar, takeMVar)
import Control.Exception (SomeException, throwIO, try)
import Control.Monad (replicateM_)
import Data.Foldable (for_)

type Slot result = MVar (Either SomeException result)

mapConcurrently :: Int -> (item -> IO result) -> [item] -> IO [result]
mapConcurrently jobs transform items
  | workers <= 1 = traverse transform items
  | otherwise = do
      slots <- traverse (const newEmptyMVar) items
      pending <- newMVar (zip items slots)
      replicateM_ workers (forkIO (work pending))
      completed <- traverse takeMVar slots
      traverse (either throwIO pure) completed
 where
  workers = min jobs (length items)
  work pending = do
    next <- modifyMVar pending (pure . take')
    for_ next $ \(item, slot) -> do
      try (transform item) >>= putMVar slot
      work pending
  take' :: [(item, Slot result)] -> ([(item, Slot result)], Maybe (item, Slot result))
  take' [] = ([], Nothing)
  take' (next : remaining) = (remaining, Just next)
