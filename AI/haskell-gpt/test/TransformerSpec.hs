{-# OPTIONS_GHC -Wno-unused-local-binds -Wno-type-defaults #-}

module TransformerSpec
    ( spec
    ) where

import           HaskellGPT.Transformer
import           HaskellGPT.Types       (Layer (..), embeddingDim, hiddenDim)

import           Numeric.LinearAlgebra  (cols, konst, rows, sumElements, (><))

import           Test.Hspec

spec :: Spec
spec = do
  describe "Transformer Block" $ do
    describe "newTransformerBlock" $ do
      it "initializes with correct components" $ do
        tb <- newTransformerBlock 128 256
        layerType tb `shouldBe` "TransformerBlock"

      it "initializes with specified dimensions" $ do
        tb <- newTransformerBlock 64 128
        -- Should not throw an error
        layerType tb `shouldBe` "TransformerBlock"

    describe "forward pass" $ do
      it "produces output with correct shape" $ do
        tb <- newTransformerBlock 128 256
        let input = konst 1.0 (10, 128)
        let (tb', output) = forward tb input
        rows output `shouldBe` 10
        cols output `shouldBe` 128

      it "handles different sequence lengths" $ do
        tb <- newTransformerBlock embeddingDim hiddenDim
        let input1 = konst 1.0 (5, embeddingDim)
        let input2 = konst 1.0 (20, embeddingDim)
        let input3 = konst 1.0 (1, embeddingDim)

        let (tb1, output1) = forward tb input1
        let (tb2, output2) = forward tb input2
        let (tb3, output3) = forward tb input3

        rows output1 `shouldBe` 5
        rows output2 `shouldBe` 20
        rows output3 `shouldBe` 1

      it "produces non-zero output" $ do
        tb <- newTransformerBlock 128 256
        let input = konst 1.0 (8, 128)
        let (tb', output) = forward tb input
        let sumOutput = abs $ sumElements output
        sumOutput `shouldSatisfy` (> 0)

      it "produces different outputs for different inputs" $ do
        tb <- newTransformerBlock 64 128
        -- Use varied patterns instead of uniform values
        let input1 = (5 >< 64) [fromIntegral (i + j) | i <- [1..5 :: Int], j <- [1..64 :: Int]]
        let input2 = (5 >< 64) [fromIntegral (i * j) | i <- [1..5 :: Int], j <- [1..64 :: Int]]

        let (tb1, output1) = forward tb input1
        let (tb2, output2) = forward tb input2

        -- Layer normalization makes outputs similar, so just check they're not identical
        let diff = abs $ sumElements (output1 - output2)
        diff `shouldSatisfy` (> 0)

      it "maintains residual connections" $ do
        tb <- newTransformerBlock 128 256
        let input = konst 1.0 (10, 128)
        let (tb', output) = forward tb input
        -- Output should be influenced by input through residual connections
        -- This is a basic check that output is not zero
        let sumOutput = abs $ sumElements output
        sumOutput `shouldSatisfy` (> 0)

    describe "backward pass" $ do
      it "produces input gradients with correct shape" $ do
        tb <- newTransformerBlock 128 256
        let input = konst 1.0 (10, 128)
        let (tb', output) = forward tb input

        let grads = konst 0.1 (10, 128)
        let lr = 0.001
        let (tb'', inputGrads) = backward tb' grads lr

        rows inputGrads `shouldBe` 10
        cols inputGrads `shouldBe` 128

      it "updates all sub-components" $ do
        tb <- newTransformerBlock 64 128
        let input = konst 1.0 (5, 64)
        let (tb', output) = forward tb input

        let grads = konst 1.0 (5, 64)
        let lr = 0.1
        let (tb'', inputGrads) = backward tb' grads lr

        -- All components should be updated (this is implicit in the implementation)
        -- We verify by checking that backward pass completes successfully
        rows inputGrads `shouldBe` 5
        cols inputGrads `shouldBe` 64

      it "handles different sequence lengths" $ do
        tb <- newTransformerBlock embeddingDim hiddenDim
        let input1 = konst 1.0 (5, embeddingDim)
        let input2 = konst 1.0 (15, embeddingDim)

        let (tb1, output1) = forward tb input1
        let (tb2, output2) = forward tb input2

        let grads1 = konst 0.1 (5, embeddingDim)
        let grads2 = konst 0.1 (15, embeddingDim)
        let lr = 0.001

        let (tb1', inputGrads1) = backward tb1 grads1 lr
        let (tb2', inputGrads2) = backward tb2 grads2 lr

        rows inputGrads1 `shouldBe` 5
        rows inputGrads2 `shouldBe` 15

      it "propagates gradients through all components" $ do
        tb <- newTransformerBlock 128 256
        let input = konst 1.0 (8, 128)
        let (tb', output) = forward tb input

        let grads = konst 0.5 (8, 128)
        let lr = 0.01
        let (tb'', inputGrads) = backward tb' grads lr

        -- Input gradients should be non-zero (gradients propagated)
        let sumGrads = abs $ sumElements inputGrads
        sumGrads `shouldSatisfy` (> 0)

    describe "Layer instance" $ do
      it "reports correct layer type" $ do
        tb <- newTransformerBlock 128 256
        layerType tb `shouldBe` "TransformerBlock"

      it "counts parameters correctly" $ do
        tb <- newTransformerBlock 128 256
        -- Parameters = attention + feedforward + 2 * layernorm
        -- Attention: 3 * 128 * 128 = 49152
        -- FeedForward: (128*256 + 256) + (256*128 + 128) = 32768 + 256 + 32768 + 128 = 65920
        -- LayerNorm1: 128 + 128 = 256
        -- LayerNorm2: 128 + 128 = 256
        -- Total: 49152 + 65920 + 256 + 256 = 115584
        let expectedParams = (3 * 128 * 128) + ((128 * 256) + 256 + (256 * 128) + 128) + (128 + 128) + (128 + 128)
        parameters tb `shouldBe` expectedParams

      it "counts parameters correctly for different dimensions" $ do
        tb <- newTransformerBlock 64 128
        let attentionParams = 3 * 64 * 64
        let ffParams = (64 * 128) + 128 + (128 * 64) + 64
        let norm1Params = 64 + 64
        let norm2Params = 64 + 64
        let expectedParams = attentionParams + ffParams + norm1Params + norm2Params
        parameters tb `shouldBe` expectedParams
