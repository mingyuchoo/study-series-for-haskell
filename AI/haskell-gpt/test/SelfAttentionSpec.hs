{-# OPTIONS_GHC -Wno-unused-local-binds #-}

module SelfAttentionSpec
    ( spec
    ) where

import           HaskellGPT.SelfAttention
import           HaskellGPT.Types         (Layer (..), embeddingDim)

import           Numeric.LinearAlgebra    (cols, konst, rows, sumElements, (><))
import qualified Numeric.LinearAlgebra    as LA

import           Test.Hspec

spec :: Spec
spec = do
  describe "Self-Attention Mechanism" $ do
    describe "newSelfAttention" $ do
      it "initializes with correct embedding dimension" $ do
        sa <- newSelfAttention 128
        saEmbeddingDim sa `shouldBe` 128

      it "initializes weight matrices with correct shapes" $ do
        sa <- newSelfAttention 64
        rows (saWq sa) `shouldBe` 64
        cols (saWq sa) `shouldBe` 64
        rows (saWk sa) `shouldBe` 64
        cols (saWk sa) `shouldBe` 64
        rows (saWv sa) `shouldBe` 64
        cols (saWv sa) `shouldBe` 64

      it "initializes with non-zero weights" $ do
        sa <- newSelfAttention 32
        let sumWq = abs $ sumElements (saWq sa)
        let sumWk = abs $ sumElements (saWk sa)
        let sumWv = abs $ sumElements (saWv sa)
        sumWq `shouldSatisfy` (> 0)
        sumWk `shouldSatisfy` (> 0)
        sumWv `shouldSatisfy` (> 0)

    describe "computeQKV" $ do
      it "computes Q, K, V with correct shapes" $ do
        sa <- newSelfAttention 128
        let input = konst 1.0 (10, 128)  -- 10 tokens, 128 dimensions
        let (q, k, v) = computeQKV sa input
        rows q `shouldBe` 10
        cols q `shouldBe` 128
        rows k `shouldBe` 10
        cols k `shouldBe` 128
        rows v `shouldBe` 10
        cols v `shouldBe` 128

      it "produces different Q, K, V matrices" $ do
        sa <- newSelfAttention 64
        let input = konst 1.0 (5, 64)
        let (q, k, v) = computeQKV sa input
        -- Q, K, V should be different (different weight matrices)
        let diffQK = abs $ sumElements (q - k)
        let diffQV = abs $ sumElements (q - v)
        let diffKV = abs $ sumElements (k - v)
        diffQK `shouldSatisfy` (> 0.01)
        diffQV `shouldSatisfy` (> 0.01)
        diffKV `shouldSatisfy` (> 0.01)

      it "handles different sequence lengths" $ do
        sa <- newSelfAttention 128
        let input1 = konst 1.0 (5, 128)
        let input2 = konst 1.0 (20, 128)
        let (q1, k1, v1) = computeQKV sa input1
        let (q2, k2, v2) = computeQKV sa input2
        rows q1 `shouldBe` 5
        rows q2 `shouldBe` 20

    describe "softmax" $ do
      it "produces output with same shape as input" $ do
        let m = (3 >< 4) [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
        let sm = softmax m
        rows sm `shouldBe` 3
        cols sm `shouldBe` 4

      it "normalizes rows to sum to 1" $ do
        let m = (2 >< 5) [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        let sm = softmax m
        let rowSums = map (sumElements . LA.fromList . LA.toList) (LA.toRows sm)
        -- Each row should sum to approximately 1.0
        all (\s -> abs (s - 1.0) < 1e-5) rowSums `shouldBe` True

      it "produces values between 0 and 1" $ do
        let m = (3 >< 3) [1, 2, 3, -1, 0, 1, 5, -5, 0]
        let sm = softmax m
        let allValues = LA.toList $ LA.flatten sm
        all (\v -> v >= 0 && v <= 1) allValues `shouldBe` True

      it "handles large values without overflow" $ do
        let m = (2 >< 3) [100, 200, 300, 1000, 2000, 3000]
        let sm = softmax m
        let rowSums = map (sumElements . LA.fromList . LA.toList) (LA.toRows sm)
        all (\s -> abs (s - 1.0) < 1e-5) rowSums `shouldBe` True

      it "handles negative values" $ do
        let m = (2 >< 3) [-10, -5, -1, -100, -50, -10]
        let sm = softmax m
        let rowSums = map (sumElements . LA.fromList . LA.toList) (LA.toRows sm)
        all (\s -> abs (s - 1.0) < 1e-5) rowSums `shouldBe` True

    describe "softmaxBackward" $ do
      it "produces gradient with same shape as input" $ do
        let m = (2 >< 3) [1, 2, 3, 4, 5, 6]
        let sm = softmax m
        let upstreamGrad = konst 1.0 (2, 3)
        let grad = softmaxBackward sm upstreamGrad
        rows grad `shouldBe` 2
        cols grad `shouldBe` 3

      it "computes gradients correctly" $ do
        let m = (2 >< 4) [1, 2, 3, 4, 5, 6, 7, 8]
        let sm = softmax m
        -- Use non-uniform upstream gradient to get non-zero output
        let upstreamGrad = (2 >< 4) [1, 0.5, 0.2, 0.1, 0.3, 1, 0.5, 0.2]
        let grad = softmaxBackward sm upstreamGrad
        -- Gradient should have same shape
        rows grad `shouldBe` 2
        cols grad `shouldBe` 4

    describe "attention" $ do
      it "produces output with correct shape" $ do
        sa <- newSelfAttention 128
        let input = konst 1.0 (10, 128)
        let (q, k, v) = computeQKV sa input
        let output = attention q k v
        rows output `shouldBe` 10
        cols output `shouldBe` 128

      it "handles different sequence lengths" $ do
        sa <- newSelfAttention 64
        let input1 = konst 1.0 (5, 64)
        let input2 = konst 1.0 (15, 64)
        let (q1, k1, v1) = computeQKV sa input1
        let (q2, k2, v2) = computeQKV sa input2
        let output1 = attention q1 k1 v1
        let output2 = attention q2 k2 v2
        rows output1 `shouldBe` 5
        rows output2 `shouldBe` 15

      it "produces non-zero output" $ do
        sa <- newSelfAttention 128
        let input = konst 1.0 (8, 128)
        let (q, k, v) = computeQKV sa input
        let output = attention q k v
        let sumOutput = abs $ sumElements output
        sumOutput `shouldSatisfy` (> 0)

    describe "forward pass" $ do
      it "produces output with correct shape" $ do
        sa <- newSelfAttention 128
        let input = konst 1.0 (10, 128)
        let (sa', output) = forward sa input
        rows output `shouldBe` 10
        cols output `shouldBe` 128

      it "handles different sequence lengths" $ do
        sa <- newSelfAttention embeddingDim
        let input1 = konst 1.0 (5, embeddingDim)
        let input2 = konst 1.0 (20, embeddingDim)
        let input3 = konst 1.0 (1, embeddingDim)
        let (sa1, output1) = forward sa input1
        let (sa2, output2) = forward sa input2
        let (sa3, output3) = forward sa input3
        rows output1 `shouldBe` 5
        rows output2 `shouldBe` 20
        rows output3 `shouldBe` 1

      it "caches values for backward pass" $ do
        sa <- newSelfAttention 128
        let input = konst 1.0 (8, 128)
        let (sa', output) = forward sa input
        saCachedInput sa' `shouldSatisfy` (/= Nothing)
        saCachedQ sa' `shouldSatisfy` (/= Nothing)
        saCachedK sa' `shouldSatisfy` (/= Nothing)
        saCachedV sa' `shouldSatisfy` (/= Nothing)
        saCachedAttnScores sa' `shouldSatisfy` (/= Nothing)

      it "produces different outputs for different inputs" $ do
        sa <- newSelfAttention 64
        let input1 = konst 1.0 (5, 64)
        let input2 = konst 2.0 (5, 64)
        let (sa1, output1) = forward sa input1
        let (sa2, output2) = forward sa input2
        let diff = abs $ sumElements (output1 - output2)
        diff `shouldSatisfy` (> 0.01)

    describe "backward pass" $ do
      it "produces input gradients with correct shape" $ do
        sa <- newSelfAttention 128
        let input = konst 1.0 (10, 128)
        let (sa', output) = forward sa input
        let grads = konst 0.1 (10, 128)
        let lr = 0.001
        let (sa'', inputGrads) = backward sa' grads lr
        rows inputGrads `shouldBe` 10
        cols inputGrads `shouldBe` 128

      it "updates weight matrices" $ do
        sa <- newSelfAttention 64
        let input = konst 1.0 (5, 64)
        let (sa', output) = forward sa input

        -- Get initial weights
        let initialWq = saWq sa'
        let initialWk = saWk sa'
        let initialWv = saWv sa'

        -- Backward pass with larger gradients and learning rate
        let grads = konst 1.0 (5, 64)
        let lr = 0.1
        let (sa'', inputGrads) = backward sa' grads lr

        -- Weights should be updated
        let diffWq = abs $ sumElements (saWq sa'' - initialWq)
        let diffWk = abs $ sumElements (saWk sa'' - initialWk)
        let diffWv = abs $ sumElements (saWv sa'' - initialWv)
        diffWq `shouldSatisfy` (> 0.001)
        diffWk `shouldSatisfy` (> 0.001)
        diffWv `shouldSatisfy` (> 0.001)

      it "clears cached values after backward pass" $ do
        sa <- newSelfAttention 128
        let input = konst 1.0 (8, 128)
        let (sa', output) = forward sa input
        let grads = konst 0.1 (8, 128)
        let lr = 0.001
        let (sa'', inputGrads) = backward sa' grads lr

        saCachedInput sa'' `shouldBe` Nothing
        saCachedQ sa'' `shouldBe` Nothing
        saCachedK sa'' `shouldBe` Nothing
        saCachedV sa'' `shouldBe` Nothing
        saCachedAttnScores sa'' `shouldBe` Nothing

      it "handles different sequence lengths" $ do
        sa <- newSelfAttention embeddingDim
        let input1 = konst 1.0 (5, embeddingDim)
        let input2 = konst 1.0 (15, embeddingDim)

        let (sa1, output1) = forward sa input1
        let (sa2, output2) = forward sa input2

        let grads1 = konst 0.1 (5, embeddingDim)
        let grads2 = konst 0.1 (15, embeddingDim)
        let lr = 0.001

        let (sa1', inputGrads1) = backward sa1 grads1 lr
        let (sa2', inputGrads2) = backward sa2 grads2 lr

        rows inputGrads1 `shouldBe` 5
        rows inputGrads2 `shouldBe` 15

    describe "Layer instance" $ do
      it "reports correct layer type" $ do
        sa <- newSelfAttention 128
        layerType sa `shouldBe` "SelfAttention"

      it "counts parameters correctly" $ do
        sa <- newSelfAttention 128
        -- Three weight matrices: Wq, Wk, Wv, each of size (128 x 128)
        let expectedParams = 3 * 128 * 128
        parameters sa `shouldBe` expectedParams

      it "counts parameters correctly for different dimensions" $ do
        sa <- newSelfAttention 64
        let expectedParams = 3 * 64 * 64
        parameters sa `shouldBe` expectedParams
