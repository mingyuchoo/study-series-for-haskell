module Main
  where

-- import           Chapter02.StartingOut
-- import           Chapter03.TypesAndTypeclasses
-- import           Chapter04.SyntaxInFunctions
-- import           Chapter05.Recursion
-- import           Chapter06.HigherOrderFunctions
-- import           Chapter07.Modules
-- import           Chapter08.MakingOurOwnTypesAndTypeclasses
-- import           Chapter09.InputAndOutput
-- import           Chapter10.FunctionallySolvingProblems
-- import           Chapter11.FunctorsApplicativeFunctorsAndMonoids
-- import           Chapter12.AFistfulOfMonads
-- import           Chapter13.ForAFewMonadsMore

import System.IO (BufferMode (NoBuffering), hSetBuffering, stdout)

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
