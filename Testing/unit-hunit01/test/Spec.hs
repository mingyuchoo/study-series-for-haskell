import ExampleHUnit qualified as U

import Control.Monad (unless)
import System.Exit (exitFailure)
import System.IO (BufferMode (NoBuffering), hSetBuffering, stdout)
import Test.HUnit (errors, failures)

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  testCounts <- U.call
  unless (errors testCounts == 0 && failures testCounts == 0) exitFailure
