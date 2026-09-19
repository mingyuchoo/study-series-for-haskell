-- | core 테스트 진입점입니다.
--
-- 여기의 테스트는 저장소나 네트워크 없이 실행되는 순수 도메인 규칙 검증입니다.
-- 범주 구분은 @tests/unit/README.md@를 따릅니다.
module Main (main) where

import Test.Hspec (hspec)
import qualified Todo.Core.FilterSpec
import qualified Todo.Core.StatusSpec
import qualified Todo.Core.UseCaseSpec
import qualified Todo.Core.ValidationSpec

main :: IO ()
main = hspec $ do
  Todo.Core.StatusSpec.spec
  Todo.Core.ValidationSpec.spec
  Todo.Core.FilterSpec.spec
  Todo.Core.UseCaseSpec.spec
