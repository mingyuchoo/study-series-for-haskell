import ExampleHUnit qualified as U

import System.IO (BufferMode (NoBuffering), hSetBuffering, stdout)

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  _ <- U.call
  return ()
