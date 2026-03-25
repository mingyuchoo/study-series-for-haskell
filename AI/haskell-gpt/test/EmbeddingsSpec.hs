{-# OPTIONS_GHC -Wno-unused-local-binds -Wno-type-defaults #-}

module EmbeddingsSpec
    ( spec
    ) where

import           HaskellGPT.Embeddings
import           HaskellGPT.Types      (Layer (..), embeddingDim, maxSeqLen)
import           HaskellGPT.Vocab      (defaultVocab, vocabSize)

import           Numeric.LinearAlgebra (cols, konst, rows, (><))
import qualified Numeric.LinearAlgebra as LA

import           Test.Hspec

spec :: Spec
spec = do
  describe "Embeddings Layer" $ do
    describe "initTokenEmbeddings" $ do
      it "initializes with correct shape" $ do
        tokenEmb <- initTokenEmbeddings 100 128
        rows tokenEmb `shouldBe` 100
        cols tokenEmb `shouldBe` 128

      it "initializes with non-zero values" $ do
        tokenEmb <- initTokenEmbeddings 50 64
        let sumVal = abs $ LA.sumElements tokenEmb
        sumVal `shouldSatisfy` (> 0)

    describe "initPositionalEmbeddings" $ do
      it "initializes with correct shape" $ do
        let posEmb = initPositionalEmbeddings 80 128
        rows posEmb `shouldBe` 80
        cols posEmb `shouldBe` 128

      it "generates sinusoidal pattern" $ do
        let posEmb = initPositionalEmbeddings 10 4
        -- Check that values are within reasonable range for sin/cos
        let allValues = LA.toList $ LA.flatten posEmb
        all (\v -> abs v <= 1.5) allValues `shouldBe` True

      it "has different values for different positions" $ do
        let posEmb = initPositionalEmbeddings 10 8
        let row0 = posEmb LA.? [0]
        let row1 = posEmb LA.? [1]
        -- Rows should be different
        let diff = LA.sumElements $ LA.cmap abs (row0 - row1)
        diff `shouldSatisfy` (> 0.1)

    describe "newEmbeddings" $ do
      it "creates embeddings with correct vocabulary size" $ do
        let vocab = defaultVocab
        emb <- newEmbeddings vocab
        rows (embTokenEmbeddings emb) `shouldBe` vocabSize vocab
        cols (embTokenEmbeddings emb) `shouldBe` embeddingDim

      it "creates positional embeddings with max sequence length" $ do
        let vocab = defaultVocab
        emb <- newEmbeddings vocab
        rows (embPositionalEmbeddings emb) `shouldBe` maxSeqLen
        cols (embPositionalEmbeddings emb) `shouldBe` embeddingDim

      it "initializes optimizers" $ do
        let vocab = defaultVocab
        emb <- newEmbeddings vocab
        -- Check that optimizers exist (they should not cause errors)
        layerType emb `shouldBe` "Embeddings"

    describe "embedTokens" $ do
      it "retrieves embeddings for token IDs" $ do
        let vocab = defaultVocab
        emb <- newEmbeddings vocab
        let tokenIds = [0, 1, 2]
        let embedded = embedTokens emb tokenIds
        rows embedded `shouldBe` 3
        cols embedded `shouldBe` embeddingDim

      it "returns different embeddings for different tokens" $ do
        let vocab = defaultVocab
        emb <- newEmbeddings vocab
        let tokenIds = [0, 1]
        let embedded = embedTokens emb tokenIds
        let emb0 = embedded LA.? [0]
        let emb1 = embedded LA.? [1]
        -- Embeddings should be different
        let diff = LA.sumElements $ LA.cmap abs (emb0 - emb1)
        diff `shouldSatisfy` (> 0.01)

      it "handles single token" $ do
        let vocab = defaultVocab
        emb <- newEmbeddings vocab
        let tokenIds = [5]
        let embedded = embedTokens emb tokenIds
        rows embedded `shouldBe` 1
        cols embedded `shouldBe` embeddingDim

    describe "forward pass" $ do
      it "produces output with correct shape" $ do
        let vocab = defaultVocab
        emb <- newEmbeddings vocab
        -- Input: token IDs as a matrix (1 x seq_len)
        let input = (1 >< 5) [0, 1, 2, 3, 4]
        let (emb', output) = forward emb input
        rows output `shouldBe` 5
        cols output `shouldBe` embeddingDim

      it "adds positional embeddings to token embeddings" $ do
        let vocab = defaultVocab
        emb <- newEmbeddings vocab
        let input = (1 >< 3) [0, 1, 2]
        let (emb', output) = forward emb input

        -- Get token embeddings alone
        let tokenEmb = embedTokens emb [0, 1, 2]

        -- Output should be different from token embeddings alone
        -- (because positional embeddings are added)
        let diff = LA.sumElements $ LA.cmap abs (output - tokenEmb)
        diff `shouldSatisfy` (> 0.1)

      it "caches input for backward pass" $ do
        let vocab = defaultVocab
        emb <- newEmbeddings vocab
        let input = (1 >< 4) [0, 1, 2, 3]
        let (emb', output) = forward emb input
        embCachedInput emb' `shouldSatisfy` (/= Nothing)

      it "handles maximum sequence length" $ do
        let vocab = defaultVocab
        emb <- newEmbeddings vocab
        -- Create input with max sequence length
        let tokenIds = take maxSeqLen $ cycle [0, 1, 2, 3, 4]
        let input = (1 >< maxSeqLen) (map fromIntegral tokenIds)
        let (emb', output) = forward emb input
        rows output `shouldBe` maxSeqLen
        cols output `shouldBe` embeddingDim

    describe "backward pass" $ do
      it "computes gradients with correct shape" $ do
        let vocab = defaultVocab
        emb <- newEmbeddings vocab
        let input = (1 >< 3) [0, 1, 2]
        let (emb', output) = forward emb input

        -- Create gradient matrix (same shape as output)
        let grads = konst 0.1 (3, embeddingDim)
        let lr = 0.001
        let (emb'', inputGrads) = backward emb' grads lr

        -- Input gradients should have shape (1, seq_len)
        rows inputGrads `shouldBe` 1
        cols inputGrads `shouldBe` 3

      it "updates token embeddings" $ do
        let vocab = defaultVocab
        emb <- newEmbeddings vocab
        let input = (1 >< 3) [0, 1, 2]
        let (emb', output) = forward emb input

        -- Get initial token embeddings
        let initialTokenEmb = embTokenEmbeddings emb'

        -- Backward pass with gradients
        let grads = konst 0.5 (3, embeddingDim)
        let lr = 0.01
        let (emb'', inputGrads) = backward emb' grads lr

        -- Token embeddings should be updated
        let updatedTokenEmb = embTokenEmbeddings emb''
        let diff = LA.sumElements $ LA.cmap abs (updatedTokenEmb - initialTokenEmb)
        diff `shouldSatisfy` (> 0.0001)

      it "clears cached input after backward pass" $ do
        let vocab = defaultVocab
        emb <- newEmbeddings vocab
        let input = (1 >< 3) [0, 1, 2]
        let (emb', output) = forward emb input

        let grads = konst 0.1 (3, embeddingDim)
        let lr = 0.001
        let (emb'', inputGrads) = backward emb' grads lr

        embCachedInput emb'' `shouldBe` Nothing

    describe "Layer instance" $ do
      it "reports correct layer type" $ do
        let vocab = defaultVocab
        emb <- newEmbeddings vocab
        layerType emb `shouldBe` "Embeddings"

      it "counts parameters correctly" $ do
        let vocab = defaultVocab
        emb <- newEmbeddings vocab
        let vocabSz = vocabSize vocab
        let expectedParams = (vocabSz * embeddingDim) + (maxSeqLen * embeddingDim)
        parameters emb `shouldBe` expectedParams
