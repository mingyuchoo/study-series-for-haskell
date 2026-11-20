module GitPuller.Infrastructure.Descriptors (
  budget,
  limitTo,
)
where

import System.Posix.Resource (
  Resource (ResourceOpenFiles),
  ResourceLimit (..),
  ResourceLimits (..),
  getResourceLimit,
  setResourceLimit,
 )

budget :: Int -> Integer
budget jobs = max 1024 (64 + 4 * toInteger jobs)

bounded :: Integer -> ResourceLimit -> ResourceLimit
bounded allowance current = case current of
  ResourceLimit allowed -> ResourceLimit (min allowed allowance)
  ResourceLimitInfinity -> ResourceLimit allowance
  ResourceLimitUnknown -> ResourceLimit allowance

limitTo :: Integer -> IO ()
limitTo allowance = do
  limits <- getResourceLimit ResourceOpenFiles
  setResourceLimit ResourceOpenFiles limits{softLimit = bounded allowance (softLimit limits)}
