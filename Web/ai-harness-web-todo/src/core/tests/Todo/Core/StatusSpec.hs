-- | 상태 기계 불변조건 검증입니다.
--
-- 도메인 설명은 @docs/domain/task.md@에 있으며, 이 파일은 그 설명을
-- 실행 가능한 규칙으로 고정합니다.
module Todo.Core.StatusSpec (spec) where

import Test.Hspec (Spec, describe, it, shouldBe, shouldSatisfy)
import Test.QuickCheck (forAll, (===))
import Todo.Core.Gen (arbitraryStatus)
import Todo.Core.Status (
  TransitionError (..),
  allowedTransitions,
  canTransition,
  isTerminal,
  transition,
 )
import Todo.Core.Types (Status (..))

spec :: Spec
spec = describe "Todo.Core.Status" $ do
  it "같은 상태로의 전이는 SameStatus로 거부한다" $
    transition Pending Pending `shouldBe` Left (SameStatus Pending)

  it "허용된 전이는 목표 상태를 반환한다" $
    transition Pending Done `shouldBe` Right Done

  it "보관은 종료 상태이며 나가는 전이가 없다" $ do
    allowedTransitions Archived `shouldBe` []
    Archived `shouldSatisfy` isTerminal

  it "보관에서 다른 상태로 나갈 수 없다" $
    transition Archived Pending `shouldBe` Left (ForbiddenTransition Archived Pending)

  it "완료한 할 일은 다시 열 수 있다" $
    transition Done Pending `shouldBe` Right Pending

  it "어떤 상태도 자기 자신을 허용 전이 목록에 담지 않는다" $
    forAll arbitraryStatus $ \s ->
      (s `elem` allowedTransitions s) === False

  it "canTransition과 transition의 판단이 일치한다" $
    forAll arbitraryStatus $ \from ->
      forAll arbitraryStatus $ \to ->
        let allowed = canTransition from to
            applied = case transition from to of
              Right _ -> True
              Left _ -> False
         in allowed === applied
