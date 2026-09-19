-- | store 테스트 진입점입니다.
--
-- 임시 디렉터리에 실제 SQLite 파일을 만들어 검증하는 통합 및 회귀 테스트입니다.
-- 범주 구분은 @tests/integration/README.md@와 @tests/regression/README.md@를 따릅니다.
module Main (main) where

import Test.Hspec (hspec)
import qualified Todo.Store.RegressionSpec
import qualified Todo.Store.SqliteSpec

main :: IO ()
main = hspec $ do
  Todo.Store.SqliteSpec.spec
  Todo.Store.RegressionSpec.spec
