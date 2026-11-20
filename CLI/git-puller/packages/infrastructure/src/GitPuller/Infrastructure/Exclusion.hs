module GitPuller.Infrastructure.Exclusion
  ( Exclusion
  , new
  , within
  ) where

import Control.Concurrent.MVar (MVar, modifyMVar, newMVar, withMVar)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map

newtype Exclusion = Exclusion (MVar (Map FilePath (MVar ())))

new :: IO Exclusion
new = Exclusion <$> newMVar Map.empty

within :: Exclusion -> FilePath -> IO result -> IO result
within (Exclusion registry) resource action = do
  lock <- modifyMVar registry claim
  withMVar lock (const action)
  where
    claim locks = case Map.lookup resource locks of
      Just lock -> pure (locks, lock)
      Nothing -> do
        lock <- newMVar ()
        pure (Map.insert resource lock locks, lock)
