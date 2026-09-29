module Main (main) where

import Control.Monad (unless)
import SajuModel
import System.Exit (exitFailure)

main :: IO ()
main = do
  putStrLn "Running MySaju tests..."
  let expectedStrengths =
        [ InformationInterpretation
        , Execution
        , Monetization
        , Governance
        , SystemThinking
        ]
  unless (strengths mingyu == expectedStrengths) $ do
    putStrLn "Failed: strengths mingyu mismatch"
    exitFailure

  let expectedRisks =
        [ OverExpansion
        , ResourceOverload
        , ControlPressure
        ]
  unless (risks mingyu == expectedRisks) $ do
    putStrLn "Failed: risks mingyu mismatch"
    exitFailure

  putStrLn "All tests passed successfully!"
