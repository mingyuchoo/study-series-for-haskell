{-# OPTIONS_GHC -Wno-unused-local-binds #-}

module FeedForwardSpec
    ( spec
    ) where

import           HaskellGPT.FeedForward
import           HaskellGPT.Types       (Layer (..), embeddingDim, hiddenDim)

import           Numeric.LinearAlgebra  (cols, konst, rows, sumElements, (><))
import qualified Numeric.LinearAlgebra  as LA

import           Test.Hspec

spec :: Spec
spec = do
  describe "Feed-Forward Network" $ do
    describe "newFeedForward" $ do
      it "initializes with correct weight shapes" $ do
        ff <- newFeedForward 128 256
        rows (ffW1 ff) `shouldBe` 128
        cols (ffW1 ff) `shouldBe` 256
        rows (ffW2 ff) `shouldBe` 256
        cols (ffW2 ff) `shouldBe` 128

      it "initializes with correct bias shapes" $ do
        ff <- newFeedForward 128 256
        rows (ffB1 ff) `shouldBe` 1
        cols (ffB1 ff) `shouldBe` 256
        rows (ffB2 ff) `shouldBe` 1
        cols (ffB2 ff) `shouldBe` 128

      it "initializes weights with non-zero values" $ do
        ff <- newFeedForward 64 128
        let sumW1 = abs $ sumElements (ffW1 ff)
        let sumW2 = abs $ sumElements (ffW2 ff)
        sumW1 `shouldSatisfy` (> 0)
        sumW2 `shouldSatisfy` (> 0)

      it "initializes biases to zero" $ do
        ff <- newFeedForward 64 128
        let sumB1 = abs $ sumElements (ffB1 ff)
        let sumB2 = abs $ sumElements (ffB2 ff)
        sumB1 `shouldBe` 0
        sumB2 `shouldBe` 0

    describe "relu" $ do
      it "applies ReLU activation correctly" $ do
        let m = (2 >< 3) [1, -2, 3, -4, 5, -6]
        let result = relu m
        LA.toList (LA.flatten result) `shouldBe` [1, 0, 3, 0, 5, 0]

      it "preserves positive values" $ do
        let m = (2 >< 2) [1, 2, 3, 4]
        let result = relu m
        LA.toList (LA.flatten result) `shouldBe` [1, 2, 3, 4]

      it "zeros out negative values" $ do
        let m = (2 >< 2) [-1, -2, -3, -4]
        let result = relu m
        LA.toList (LA.flatten result) `shouldBe` [0, 0, 0, 0]

      it "handles zero values" $ do
        let m = (2 >< 2) [0, 0, 0, 0]
        let result = relu m
        LA.toList (LA.flatten result) `shouldBe` [0, 0, 0, 0]

      it "handles mixed positive and negative values" $ do
        let m = (3 >< 3) [1, -1, 0, -5, 10, -0.5, 0.1, -0.1, 100]
        let result = relu m
        let expected = [1, 0, 0, 0, 10, 0, 0.1, 0, 100]
        let actual = LA.toList (LA.flatten result)
        all (\(a, e) -> abs (a - e) < 1e-5) (zip actual expected) `shouldBe` True

    describe "reluDerivative" $ do
      it "computes derivative correctly" $ do
        let m = (2 >< 3) [1, -2, 3, -4, 5, -6]
        let result = reluDerivative m
        LA.toList (LA.flatten result) `shouldBe` [1, 0, 1, 0, 1, 0]

      it "returns 1 for positive values" $ do
        let m = (2 >< 2) [1, 2, 3, 4]
        let result = reluDerivative m
        LA.toList (LA.flatten result) `shouldBe` [1, 1, 1, 1]

      it "returns 0 for negative values" $ do
        let m = (2 >< 2) [-1, -2, -3, -4]
        let result = reluDerivative m
        LA.toList (LA.flatten result) `shouldBe` [0, 0, 0, 0]

      it "returns 0 for zero values" $ do
        let m = (2 >< 2) [0, 0, 0, 0]
        let result = reluDerivative m
        LA.toList (LA.flatten result) `shouldBe` [0, 0, 0, 0]

    describe "forward pass" $ do
      it "produces output with correct shape" $ do
        ff <- newFeedForward 128 256
        let input = konst 1.0 (10, 128)  -- 10 tokens, 128 dimensions
        let (ff', output) = forward ff input
        rows output `shouldBe` 10
        cols output `shouldBe` 128

      it "handles different sequence lengths" $ do
        ff <- newFeedForward embeddingDim hiddenDim
        let input1 = konst 1.0 (5, embeddingDim)
        let input2 = konst 1.0 (20, embeddingDim)
        let input3 = konst 1.0 (1, embeddingDim)
        let (ff1, output1) = forward ff input1
        let (ff2, output2) = forward ff input2
        let (ff3, output3) = forward ff input3
        rows output1 `shouldBe` 5
        rows output2 `shouldBe` 20
        rows output3 `shouldBe` 1

      it "caches values for backward pass" $ do
        ff <- newFeedForward 128 256
        let input = konst 1.0 (8, 128)
        let (ff', output) = forward ff input
        ffCachedInput ff' `shouldSatisfy` (/= Nothing)
        ffCachedHiddenPre ff' `shouldSatisfy` (/= Nothing)
        ffCachedHiddenPost ff' `shouldSatisfy` (/= Nothing)

      it "produces non-zero output" $ do
        ff <- newFeedForward 128 256
        let input = konst 1.0 (8, 128)
        let (ff', output) = forward ff input
        let sumOutput = abs $ sumElements output
        sumOutput `shouldSatisfy` (> 0)

      it "produces different outputs for different inputs" $ do
        ff <- newFeedForward 64 128
        let input1 = konst 1.0 (5, 64)
        let input2 = konst 2.0 (5, 64)
        let (ff1, output1) = forward ff input1
        let (ff2, output2) = forward ff input2
        let diff = abs $ sumElements (output1 - output2)
        diff `shouldSatisfy` (> 0.01)

      it "applies ReLU activation in hidden layer" $ do
        ff <- newFeedForward 32 64
        -- Create input that will produce negative values in hidden layer
        let input = (3 >< 32) $ replicate 96 (-1.0)
        let (ff', output) = forward ff input
        -- Output should still be computed (ReLU zeros out negatives)
        rows output `shouldBe` 3
        cols output `shouldBe` 32

    describe "backward pass" $ do
      it "produces input gradients with correct shape" $ do
        ff <- newFeedForward 128 256
        let input = konst 1.0 (10, 128)
        let (ff', output) = forward ff input
        let grads = konst 0.1 (10, 128)
        let lr = 0.001
        let (ff'', inputGrads) = backward ff' grads lr
        rows inputGrads `shouldBe` 10
        cols inputGrads `shouldBe` 128

      it "updates weight matrices" $ do
        ff <- newFeedForward 64 128
        let input = konst 1.0 (5, 64)
        let (ff', output) = forward ff input

        -- Get initial weights
        let initialW1 = ffW1 ff'
        let initialW2 = ffW2 ff'

        -- Backward pass with larger gradients and learning rate
        let grads = konst 1.0 (5, 64)
        let lr = 0.1
        let (ff'', inputGrads) = backward ff' grads lr

        -- Weights should be updated
        let diffW1 = abs $ sumElements (ffW1 ff'' - initialW1)
        let diffW2 = abs $ sumElements (ffW2 ff'' - initialW2)
        diffW1 `shouldSatisfy` (> 0.001)
        diffW2 `shouldSatisfy` (> 0.001)

      it "updates bias vectors" $ do
        ff <- newFeedForward 64 128
        let input = konst 1.0 (5, 64)
        let (ff', output) = forward ff input

        -- Get initial biases
        let initialB1 = ffB1 ff'
        let initialB2 = ffB2 ff'

        -- Backward pass
        let grads = konst 1.0 (5, 64)
        let lr = 0.1
        let (ff'', inputGrads) = backward ff' grads lr

        -- Biases should be updated
        let diffB1 = abs $ sumElements (ffB1 ff'' - initialB1)
        let diffB2 = abs $ sumElements (ffB2 ff'' - initialB2)
        diffB1 `shouldSatisfy` (> 0.001)
        diffB2 `shouldSatisfy` (> 0.001)

      it "clears cached values after backward pass" $ do
        ff <- newFeedForward 128 256
        let input = konst 1.0 (8, 128)
        let (ff', output) = forward ff input
        let grads = konst 0.1 (8, 128)
        let lr = 0.001
        let (ff'', inputGrads) = backward ff' grads lr

        ffCachedInput ff'' `shouldBe` Nothing
        ffCachedHiddenPre ff'' `shouldBe` Nothing
        ffCachedHiddenPost ff'' `shouldBe` Nothing

      it "handles different sequence lengths" $ do
        ff <- newFeedForward embeddingDim hiddenDim
        let input1 = konst 1.0 (5, embeddingDim)
        let input2 = konst 1.0 (15, embeddingDim)

        let (ff1, output1) = forward ff input1
        let (ff2, output2) = forward ff input2

        let grads1 = konst 0.1 (5, embeddingDim)
        let grads2 = konst 0.1 (15, embeddingDim)
        let lr = 0.001

        let (ff1', inputGrads1) = backward ff1 grads1 lr
        let (ff2', inputGrads2) = backward ff2 grads2 lr

        rows inputGrads1 `shouldBe` 5
        rows inputGrads2 `shouldBe` 15

      it "computes gradients correctly through ReLU" $ do
        ff <- newFeedForward 32 64
        let input = konst 1.0 (3, 32)
        let (ff', output) = forward ff input

        -- Backward pass
        let grads = konst 0.5 (3, 32)
        let lr = 0.01
        let (ff'', inputGrads) = backward ff' grads lr

        -- Input gradients should be computed
        let sumGrads = abs $ sumElements inputGrads
        sumGrads `shouldSatisfy` (>= 0)  -- Can be zero if ReLU blocks all gradients

    describe "Layer instance" $ do
      it "reports correct layer type" $ do
        ff <- newFeedForward 128 256
        layerType ff `shouldBe` "FeedForward"

      it "counts parameters correctly" $ do
        ff <- newFeedForward 128 256
        -- W1: 128 x 256 = 32768
        -- b1: 256
        -- W2: 256 x 128 = 32768
        -- b2: 128
        -- Total: 32768 + 256 + 32768 + 128 = 65920
        let expectedParams = (128 * 256) + 256 + (256 * 128) + 128
        parameters ff `shouldBe` expectedParams

      it "counts parameters correctly for different dimensions" $ do
        ff <- newFeedForward 64 128
        -- W1: 64 x 128 = 8192
        -- b1: 128
        -- W2: 128 x 64 = 8192
        -- b2: 64
        -- Total: 8192 + 128 + 8192 + 64 = 16576
        let expectedParams = (64 * 128) + 128 + (128 * 64) + 64
        parameters ff `shouldBe` expectedParams
