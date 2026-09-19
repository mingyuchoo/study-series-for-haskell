-- | cli 테스트 진입점입니다.
--
-- 명령줄 문법과 출력 형식은 사용자와 다른 도구가 의존하는 표면이므로
-- 순수 함수 수준에서 고정합니다.
module Main (main) where

import Test.Hspec (hspec)
import qualified Todo.Cli.OptionsSpec
import qualified Todo.Cli.RenderSpec

main :: IO ()
main = hspec $ do
  Todo.Cli.OptionsSpec.spec
  Todo.Cli.RenderSpec.spec
