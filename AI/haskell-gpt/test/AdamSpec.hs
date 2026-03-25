module AdamSpec
    ( spec
    ) where

import           HaskellGPT.Adam

import           Numeric.LinearAlgebra (cols, konst, rows)
import qualified Numeric.LinearAlgebra as LA

import           Test.Hspec

spec :: Spec
spec = do
  describe "Adam Optimizer" $ do
    describe "initAdam" $ do
      it "initializes with correct shape" $ do
        let adam = initAdam (3, 4)
        rows (adamM adam) `shouldBe` 3
        cols (adamM adam) `shouldBe` 4
        rows (adamV adam) `shouldBe` 3
        cols (adamV adam) `shouldBe` 4

      it "initializes with default hyperparameters" $ do
        let adam = initAdam (2, 2)
        adamBeta1 adam `shouldBe` 0.9
        adamBeta2 adam `shouldBe` 0.999
        adamEpsilon adam `shouldBe` 1e-8
        adamTimestep adam `shouldBe` 0

      it "initializes momentum matrices to zero" $ do
        let adam = initAdam (2, 3)
        let mSum = LA.sumElements (adamM adam)
        let vSum = LA.sumElements (adamV adam)
        mSum `shouldBe` 0.0
        vSum `shouldBe` 0.0

    describe "stepAdam" $ do
      it "performs single step parameter update" $ do
        let adam = initAdam (2, 2)
        let params = konst 1.0 (2, 2)
        let grads = konst 0.1 (2, 2)
        let lr = 0.001
        let (newAdam, newParams) = stepAdam adam params grads lr

        -- Timestep should increment
        adamTimestep newAdam `shouldBe` 1

        -- Parameters should be updated (decreased since gradients are positive)
        let paramSum = LA.sumElements params
        let newParamSum = LA.sumElements newParams
        newParamSum `shouldSatisfy` (< paramSum)

      it "updates momentum matrices" $ do
        let adam = initAdam (2, 2)
        let params = konst 1.0 (2, 2)
        let grads = konst 0.5 (2, 2)
        let lr = 0.01
        let (newAdam, _) = stepAdam adam params grads lr

        -- First moment should be non-zero after update
        let mSum = LA.sumElements (adamM newAdam)
        mSum `shouldSatisfy` (> 0)

        -- Second moment should be non-zero after update
        let vSum = LA.sumElements (adamV newAdam)
        vSum `shouldSatisfy` (> 0)

      it "converges over multiple steps" $ do
        let adam = initAdam (2, 2)
        let params = konst 5.0 (2, 2)
        let grads = konst 1.0 (2, 2)  -- Constant gradient pointing down
        let lr = 0.1

        -- Perform 10 optimization steps
        let (_, finalParams) = iterate (\(a, p) -> stepAdam a p grads lr) (adam, params) !! 10

        -- Parameters should decrease significantly
        let initialSum = LA.sumElements params
        let finalSum = LA.sumElements finalParams
        finalSum `shouldSatisfy` (< initialSum)

        -- Should show convergence (parameters decrease by at least 10%)
        finalSum `shouldSatisfy` (< initialSum * 0.9)

      it "handles zero gradients correctly" $ do
        let adam = initAdam (2, 2)
        let params = konst 1.0 (2, 2)
        let grads = konst 0.0 (2, 2)
        let lr = 0.01
        let (newAdam, newParams) = stepAdam adam params grads lr

        -- Timestep should still increment
        adamTimestep newAdam `shouldBe` 1

        -- Parameters should remain unchanged with zero gradients
        let paramDiff = LA.sumElements (params - newParams)
        abs paramDiff `shouldSatisfy` (< 1e-6)

      it "handles negative gradients correctly" $ do
        let adam = initAdam (2, 2)
        let params = konst 1.0 (2, 2)
        let grads = konst (-0.5) (2, 2)
        let lr = 0.01
        let (newAdam, newParams) = stepAdam adam params grads lr

        -- Timestep should increment
        adamTimestep newAdam `shouldBe` 1

        -- Parameters should increase (negative gradient means move up)
        let paramSum = LA.sumElements params
        let newParamSum = LA.sumElements newParams
        newParamSum `shouldSatisfy` (> paramSum)

      it "maintains momentum across multiple steps" $ do
        let adam = initAdam (2, 2)
        let params = konst 2.0 (2, 2)
        let grads = konst 0.3 (2, 2)
        let lr = 0.05

        -- First step
        let (adam1, params1) = stepAdam adam params grads lr
        let m1Sum = LA.sumElements (adamM adam1)

        -- Second step
        let (adam2, _) = stepAdam adam1 params1 grads lr
        let m2Sum = LA.sumElements (adamM adam2)

        -- Momentum should accumulate
        m2Sum `shouldSatisfy` (> m1Sum)

        -- Timestep should increment correctly
        adamTimestep adam1 `shouldBe` 1
        adamTimestep adam2 `shouldBe` 2
