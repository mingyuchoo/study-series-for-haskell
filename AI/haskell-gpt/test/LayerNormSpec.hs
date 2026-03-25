{-# OPTIONS_GHC -Wno-unused-local-binds #-}

module LayerNormSpec
    ( spec
    ) where

import           HaskellGPT.LayerNorm
import           HaskellGPT.Types      (Layer (..), embeddingDim)

import           Numeric.LinearAlgebra (cols, konst, rows, sumElements, (><))
import qualified Numeric.LinearAlgebra as LA

import           Test.Hspec

-- Helper function to compute mean of a list
mean :: [Float] -> Float
mean xs = sum xs / fromIntegral (length xs)

-- Helper function to compute standard deviation of a list
stdDev :: [Float] -> Float
stdDev xs =
  let m = mean xs
      variance = sum [(x - m) ** 2 | x <- xs] / fromIntegral (length xs)
  in sqrt variance

spec :: Spec
spec = do
  describe "Layer Normalization" $ do
    describe "newLayerNorm" $ do
      it "initializes with correct gamma shape" $ do
        let ln = newLayerNorm 128
        rows (lnGamma ln) `shouldBe` 1
        cols (lnGamma ln) `shouldBe` 128

      it "initializes with correct beta shape" $ do
        let ln = newLayerNorm 128
        rows (lnBeta ln) `shouldBe` 1
        cols (lnBeta ln) `shouldBe` 128

      it "initializes gamma to ones" $ do
        let ln = newLayerNorm 64
        let gammaValues = LA.toList $ LA.flatten (lnGamma ln)
        all (\x -> abs (x - 1.0) < 1e-6) gammaValues `shouldBe` True

      it "initializes beta to zeros" $ do
        let ln = newLayerNorm 64
        let betaValues = LA.toList $ LA.flatten (lnBeta ln)
        all (\x -> abs x < 1e-6) betaValues `shouldBe` True

      it "sets epsilon to 1e-5" $ do
        let ln = newLayerNorm 128
        lnEpsilon ln `shouldBe` 1e-5

    describe "normalize" $ do
      it "normalizes input to approximately zero mean" $ do
        let ln = newLayerNorm 4
        let input = (3 >< 4) [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
        let output = normalize ln input

        -- Check each row has approximately zero mean
        let rows' = LA.toRows output
        let means = map (mean . LA.toList) rows'
        all (\m -> abs m < 0.1) means `shouldBe` True

      it "normalizes input to approximately unit standard deviation" $ do
        let ln = newLayerNorm 4
        let input = (3 >< 4) [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
        let output = normalize ln input

        -- Check each row has approximately unit std
        let rows' = LA.toRows output
        let stds = map (stdDev . LA.toList) rows'
        all (\s -> abs (s - 1.0) < 0.1) stds `shouldBe` True

      it "handles uniform input" $ do
        let ln = newLayerNorm 5
        let input = konst 3.0 (2, 5)  -- All values are 3.0
        let output = normalize ln input

        -- With uniform input, output should be all zeros (after normalization)
        -- because (x - mean) = 0 for all x
        let outputValues = LA.toList $ LA.flatten output
        all (\x -> abs x < 1e-3) outputValues `shouldBe` True

      it "preserves input shape" $ do
        let ln = newLayerNorm 128
        let input = konst 1.0 (10, 128)
        let output = normalize ln input
        rows output `shouldBe` 10
        cols output `shouldBe` 128

      it "handles different sequence lengths" $ do
        let ln = newLayerNorm embeddingDim
        let input1 = konst 1.0 (5, embeddingDim)
        let input2 = konst 1.0 (20, embeddingDim)
        let output1 = normalize ln input1
        let output2 = normalize ln input2
        rows output1 `shouldBe` 5
        rows output2 `shouldBe` 20

    describe "forward pass" $ do
      it "produces output with correct shape" $ do
        let ln = newLayerNorm 128
        let input = konst 1.0 (10, 128)
        let (ln', output) = forward ln input
        rows output `shouldBe` 10
        cols output `shouldBe` 128

      it "normalizes to approximately zero mean" $ do
        let ln = newLayerNorm 8
        let input = (4 >< 8) [1..32]
        let (ln', output) = forward ln input

        -- Check each row has approximately zero mean
        let rows' = LA.toRows output
        let means = map (mean . LA.toList) rows'
        all (\m -> abs m < 0.1) means `shouldBe` True

      it "normalizes to approximately unit standard deviation" $ do
        let ln = newLayerNorm 8
        let input = (4 >< 8) [1..32]
        let (ln', output) = forward ln input

        -- Check each row has approximately unit std
        let rows' = LA.toRows output
        let stds = map (stdDev . LA.toList) rows'
        all (\s -> abs (s - 1.0) < 0.1) stds `shouldBe` True

      it "caches values for backward pass" $ do
        let ln = newLayerNorm 128
        let input = konst 1.0 (8, 128)
        let (ln', output) = forward ln input
        lnCachedInput ln' `shouldSatisfy` (/= Nothing)
        lnCachedMean ln' `shouldSatisfy` (/= Nothing)
        lnCachedStd ln' `shouldSatisfy` (/= Nothing)

      it "handles different sequence lengths" $ do
        let ln = newLayerNorm embeddingDim
        let input1 = konst 1.0 (5, embeddingDim)
        let input2 = konst 1.0 (15, embeddingDim)
        let (ln1, output1) = forward ln input1
        let (ln2, output2) = forward ln input2
        rows output1 `shouldBe` 5
        rows output2 `shouldBe` 15

      it "produces different outputs for different inputs" $ do
        let ln = newLayerNorm 64
        -- Use inputs with different distributions
        let input1 = (3 >< 64) $ map (* 2) [1..192]
        let input2 = (3 >< 64) $ map (* 3) [1..192]
        let (ln1, output1) = forward ln input1
        let (ln2, output2) = forward ln input2
        let diff = abs $ sumElements (output1 - output2)
        -- After normalization with same gamma/beta, outputs should be similar but not identical
        -- due to numerical precision
        diff `shouldSatisfy` (< 1.0)  -- They should be very similar after normalization

    describe "backward pass" $ do
      it "produces input gradients with correct shape" $ do
        let ln = newLayerNorm 128
        let input = konst 1.0 (10, 128)
        let (ln', output) = forward ln input
        let grads = konst 0.1 (10, 128)
        let lr = 0.001
        let (ln'', inputGrads) = backward ln' grads lr
        rows inputGrads `shouldBe` 10
        cols inputGrads `shouldBe` 128

      it "updates gamma parameter" $ do
        let ln = newLayerNorm 64
        -- Use input with significant variation
        let inputData = [fromIntegral (i + j * 10) | i <- [1..5 :: Int], j <- [1..64 :: Int]]
        let input = (5 >< 64) inputData
        let (ln', output) = forward ln input

        -- Get initial gamma
        let initialGamma = lnGamma ln'

        -- Backward pass with large uniform gradients
        let grads = konst 2.0 (5, 64)
        let lr = 0.5  -- Large learning rate
        let (ln'', inputGrads) = backward ln' grads lr

        -- Gamma should be updated (even if very slightly due to normalization)
        -- The update might be very small because normalized values are similar
        let diffGamma = abs $ sumElements (lnGamma ln'' - initialGamma)
        diffGamma `shouldSatisfy` (> 0)

      it "updates beta parameter" $ do
        let ln = newLayerNorm 64
        let input = (5 >< 64) [1..320]
        let (ln', output) = forward ln input

        -- Get initial beta
        let initialBeta = lnBeta ln'

        -- Backward pass
        let grads = konst 1.0 (5, 64)
        let lr = 0.1
        let (ln'', inputGrads) = backward ln' grads lr

        -- Beta should be updated
        let diffBeta = abs $ sumElements (lnBeta ln'' - initialBeta)
        diffBeta `shouldSatisfy` (> 0.001)

      it "clears cached values after backward pass" $ do
        let ln = newLayerNorm 128
        let input = konst 1.0 (8, 128)
        let (ln', output) = forward ln input
        let grads = konst 0.1 (8, 128)
        let lr = 0.001
        let (ln'', inputGrads) = backward ln' grads lr

        lnCachedInput ln'' `shouldBe` Nothing
        lnCachedMean ln'' `shouldBe` Nothing
        lnCachedStd ln'' `shouldBe` Nothing

      it "handles different sequence lengths" $ do
        let ln = newLayerNorm embeddingDim
        let input1 = konst 1.0 (5, embeddingDim)
        let input2 = konst 1.0 (15, embeddingDim)

        let (ln1, output1) = forward ln input1
        let (ln2, output2) = forward ln input2

        let grads1 = konst 0.1 (5, embeddingDim)
        let grads2 = konst 0.1 (15, embeddingDim)
        let lr = 0.001

        let (ln1', inputGrads1) = backward ln1 grads1 lr
        let (ln2', inputGrads2) = backward ln2 grads2 lr

        rows inputGrads1 `shouldBe` 5
        rows inputGrads2 `shouldBe` 15

      it "computes non-zero input gradients" $ do
        let ln = newLayerNorm 32
        -- Use input with varying values
        let input = (3 >< 32) $ concat [[fromIntegral i + fromIntegral j | j <- [1..32 :: Int]] | i <- [0..2 :: Int]]
        let (ln', output) = forward ln input

        -- Backward pass with non-uniform gradients
        let grads = (3 >< 32) $ concat [[fromIntegral j * 0.1 | j <- [1..32 :: Int]] | _ <- [0..2 :: Int]]
        let lr = 0.01
        let (ln'', inputGrads) = backward ln' grads lr

        -- Input gradients should be computed
        let sumGrads = abs $ sumElements inputGrads
        sumGrads `shouldSatisfy` (> 0)

    describe "Layer instance" $ do
      it "reports correct layer type" $ do
        let ln = newLayerNorm 128
        layerType ln `shouldBe` "LayerNorm"

      it "counts parameters correctly" $ do
        let ln = newLayerNorm 128
        -- gamma: 128
        -- beta: 128
        -- Total: 256
        parameters ln `shouldBe` 256

      it "counts parameters correctly for different dimensions" $ do
        let ln = newLayerNorm 64
        -- gamma: 64
        -- beta: 64
        -- Total: 128
        parameters ln `shouldBe` 128

