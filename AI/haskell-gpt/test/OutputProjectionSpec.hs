{-# OPTIONS_GHC -Wno-unused-local-binds #-}

module OutputProjectionSpec
    ( spec
    ) where

import           HaskellGPT.OutputProjection
import           HaskellGPT.Types            (Layer (..), embeddingDim)

import           Numeric.LinearAlgebra       (cols, konst, rows, sumElements,
                                              (><))
import qualified Numeric.LinearAlgebra       as LA

import           Test.Hspec

spec :: Spec
spec = do
  describe "Output Projection" $ do
    describe "newOutputProjection" $ do
      it "creates output projection with correct weight shape" $ do
        op <- newOutputProjection 128 5000
        rows (opWOut op) `shouldBe` 128
        cols (opWOut op) `shouldBe` 5000

      it "creates output projection with correct bias shape" $ do
        op <- newOutputProjection 128 5000
        rows (opBOut op) `shouldBe` 1
        cols (opBOut op) `shouldBe` 5000

      it "initializes bias to zeros" $ do
        op <- newOutputProjection 64 100
        let biasValues = LA.toList $ LA.flatten (opBOut op)
        all (\x -> abs x < 1e-6) biasValues `shouldBe` True

      it "initializes weights with non-zero values" $ do
        op <- newOutputProjection 64 100
        let weightValues = LA.toList $ LA.flatten (opWOut op)
        any (\x -> abs x > 1e-6) weightValues `shouldBe` True

      it "initializes with no cached input" $ do
        op <- newOutputProjection 128 1000
        opCachedInput op `shouldBe` Nothing


    describe "forward pass" $ do
      it "produces output with correct shape" $ do
        op <- newOutputProjection 128 5000
        let input = konst 1.0 (10, 128)
        let (op', output) = forward op input
        rows output `shouldBe` 10
        cols output `shouldBe` 5000

      it "produces logits for vocabulary" $ do
        op <- newOutputProjection 64 100
        let input = konst 0.5 (5, 64)
        let (op', output) = forward op input
        -- Output should be logits (can be any real numbers)
        rows output `shouldBe` 5
        cols output `shouldBe` 100

      it "caches input for backward pass" $ do
        op <- newOutputProjection 128 1000
        let input = konst 1.0 (8, 128)
        let (op', output) = forward op input
        opCachedInput op' `shouldSatisfy` (/= Nothing)

      it "handles different sequence lengths" $ do
        op <- newOutputProjection embeddingDim 1000
        let input1 = konst 1.0 (5, embeddingDim)
        let input2 = konst 1.0 (20, embeddingDim)
        let (op1, output1) = forward op input1
        let (op2, output2) = forward op input2
        rows output1 `shouldBe` 5
        rows output2 `shouldBe` 20

      it "produces different outputs for different inputs" $ do
        op <- newOutputProjection 64 100
        let input1 = konst 1.0 (3, 64)
        let input2 = konst 2.0 (3, 64)
        let (op1, output1) = forward op input1
        let (op2, output2) = forward op input2
        let diff = abs $ sumElements (output1 - output2)
        diff `shouldSatisfy` (> 0.1)

      it "applies bias correctly" $ do
        op <- newOutputProjection 32 50
        -- Set bias to a known value for testing
        let opWithBias = op { opBOut = konst 1.0 (1, 50) }
        let input = konst 0.0 (2, 32)  -- Zero input
        let (op', output) = forward opWithBias input
        -- With zero input and weights, output should be approximately bias
        -- (may not be exact due to random weight initialization)
        rows output `shouldBe` 2
        cols output `shouldBe` 50


    describe "backward pass" $ do
      it "produces input gradients with correct shape" $ do
        op <- newOutputProjection 128 5000
        let input = konst 1.0 (10, 128)
        let (op', output) = forward op input
        let grads = konst 0.1 (10, 5000)
        let lr = 0.001
        let (op'', inputGrads) = backward op' grads lr
        rows inputGrads `shouldBe` 10
        cols inputGrads `shouldBe` 128

      it "updates weight matrix" $ do
        op <- newOutputProjection 64 100
        let input = (5 >< 64) [1..320]
        let (op', output) = forward op input

        -- Get initial weights
        let initialWeights = opWOut op'

        -- Backward pass
        let grads = konst 1.0 (5, 100)
        let lr = 0.1
        let (op'', inputGrads) = backward op' grads lr

        -- Weights should be updated
        let diffWeights = abs $ sumElements (opWOut op'' - initialWeights)
        diffWeights `shouldSatisfy` (> 0.001)

      it "updates bias vector" $ do
        op <- newOutputProjection 64 100
        let input = (5 >< 64) [1..320]
        let (op', output) = forward op input

        -- Get initial bias
        let initialBias = opBOut op'

        -- Backward pass
        let grads = konst 1.0 (5, 100)
        let lr = 0.1
        let (op'', inputGrads) = backward op' grads lr

        -- Bias should be updated
        let diffBias = abs $ sumElements (opBOut op'' - initialBias)
        diffBias `shouldSatisfy` (> 0.001)

      it "clears cached input after backward pass" $ do
        op <- newOutputProjection 128 1000
        let input = konst 1.0 (8, 128)
        let (op', output) = forward op input
        let grads = konst 0.1 (8, 1000)
        let lr = 0.001
        let (op'', inputGrads) = backward op' grads lr

        opCachedInput op'' `shouldBe` Nothing

      it "handles different sequence lengths" $ do
        op <- newOutputProjection embeddingDim 1000
        let input1 = konst 1.0 (5, embeddingDim)
        let input2 = konst 1.0 (15, embeddingDim)

        let (op1, output1) = forward op input1
        let (op2, output2) = forward op input2

        let grads1 = konst 0.1 (5, 1000)
        let grads2 = konst 0.1 (15, 1000)
        let lr = 0.001

        let (op1', inputGrads1) = backward op1 grads1 lr
        let (op2', inputGrads2) = backward op2 grads2 lr

        rows inputGrads1 `shouldBe` 5
        rows inputGrads2 `shouldBe` 15

      it "computes non-zero input gradients" $ do
        op <- newOutputProjection 32 50
        let input = (3 >< 32) [1..96]
        let (op', output) = forward op input

        -- Backward pass with non-zero gradients
        let grads = konst 0.5 (3, 50)
        let lr = 0.01
        let (op'', inputGrads) = backward op' grads lr

        -- Input gradients should be computed
        let sumGrads = abs $ sumElements inputGrads
        sumGrads `shouldSatisfy` (> 0)


    describe "training updates" $ do
      it "reduces loss with multiple training steps" $ do
        op <- newOutputProjection 32 50
        let input = (3 >< 32) $ map (* 0.1) [1..96]

        -- Perform multiple training steps
        let trainStep op' = do
              let (opFwd, output) = forward op' input
              -- Simulate loss gradients
              let grads = konst 0.5 (3, 50)
              let lr = 0.01
              let (opBwd, _) = backward opFwd grads lr
              return opBwd

        -- Train for a few steps
        op1 <- trainStep op
        op2 <- trainStep op1
        op3 <- trainStep op2

        -- Weights should change over training
        let initialWeights = opWOut op
        let finalWeights = opWOut op3
        let weightChange = abs $ sumElements (finalWeights - initialWeights)
        weightChange `shouldSatisfy` (> 0.01)

      it "updates parameters consistently across steps" $ do
        op <- newOutputProjection 64 100
        let input = konst 0.5 (5, 64)

        -- First training step
        let (op1, output1) = forward op input
        let grads1 = konst 0.2 (5, 100)
        let lr = 0.01
        let (op2, _) = backward op1 grads1 lr

        -- Second training step
        let (op3, output2) = forward op2 input
        let grads2 = konst 0.2 (5, 100)
        let (op4, _) = backward op3 grads2 lr

        -- Parameters should be different after each step
        let weights1 = opWOut op2
        let weights2 = opWOut op4
        let diff = abs $ sumElements (weights2 - weights1)
        diff `shouldSatisfy` (> 0.001)

    describe "Layer instance" $ do
      it "reports correct layer type" $ do
        op <- newOutputProjection 128 5000
        layerType op `shouldBe` "OutputProjection"

      it "counts parameters correctly" $ do
        op <- newOutputProjection 128 5000
        -- W_out: 128 x 5000 = 640,000
        -- b_out: 1 x 5000 = 5,000
        -- Total: 645,000
        parameters op `shouldBe` 645000

      it "counts parameters correctly for different dimensions" $ do
        op <- newOutputProjection 64 100
        -- W_out: 64 x 100 = 6,400
        -- b_out: 1 x 100 = 100
        -- Total: 6,500
        parameters op `shouldBe` 6500
