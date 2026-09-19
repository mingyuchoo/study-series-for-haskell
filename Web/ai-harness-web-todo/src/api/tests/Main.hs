-- | api 테스트 진입점입니다.
--
-- 계약 테스트는 @docs/contracts/api/TODO-API-v1.md@에 게시한 약속을 검증하고,
-- 보안 테스트는 입력 검증과 오류 노출 범위를 검증합니다.
module Main (main) where

import Test.Hspec (hspec)
import qualified Todo.Api.ContractSpec
import qualified Todo.Api.SecuritySpec

main :: IO ()
main = hspec $ do
  Todo.Api.ContractSpec.spec
  Todo.Api.SecuritySpec.spec
