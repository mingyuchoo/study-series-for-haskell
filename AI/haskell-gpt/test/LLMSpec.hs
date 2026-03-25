{-# OPTIONS_GHC -Wno-unused-local-binds #-}

module LLMSpec
    ( spec
    ) where

import           HaskellGPT.Embeddings       (newEmbeddings)
import           HaskellGPT.LLM
import           HaskellGPT.OutputProjection (newOutputProjection)
import           HaskellGPT.Transformer      (newTransformerBlock)
import           HaskellGPT.Types            (SomeLayer (..), embeddingDim,
                                              hiddenDim)
import           HaskellGPT.Vocab            (defaultVocab, newVocab, vocabSize)

import           Numeric.LinearAlgebra       ((><))
import qualified Numeric.LinearAlgebra       as LA

import           Test.Hspec

spec :: Spec
spec = do
  describe "LLM Module" $ do

    describe "newLLM and basic functions" $ do
      it "creates LLM with vocabulary and network" $ do
        let vocab = defaultVocab
        emb <- newEmbeddings vocab
        let llm = newLLM vocab [SomeLayer emb]
        llmVocab llm `shouldBe` vocab
        length (llmNetwork llm) `shouldBe` 1

      it "networkDescription returns layer types" $ do
        let vocab = defaultVocab
        emb <- newEmbeddings vocab
        let llm = newLLM vocab [SomeLayer emb]
        let desc = networkDescription llm
        desc `shouldContain` "Embeddings"

      it "totalParameters counts all parameters" $ do
        let vocab = defaultVocab
        emb <- newEmbeddings vocab
        let llm = newLLM vocab [SomeLayer emb]
        let params = totalParameters llm
        params `shouldSatisfy` (> 0)

    describe "tokenization" $ do
      it "tokenizes simple text" $ do
        let vocab = defaultVocab
        emb <- newEmbeddings vocab
        let llm = newLLM vocab [SomeLayer emb]
        let tokens = tokenize llm "hello world"
        length tokens `shouldSatisfy` (> 0)

      it "handles punctuation as separate tokens" $ do
        let vocab = defaultVocab
        emb <- newEmbeddings vocab
        let llm = newLLM vocab [SomeLayer emb]
        let tokens = tokenize llm "hello, world!"
        -- Should have: hello, comma, world, exclamation
        length tokens `shouldSatisfy` (>= 4)

      it "handles special tokens" $ do
        let vocab = defaultVocab
        emb <- newEmbeddings vocab
        let llm = newLLM vocab [SomeLayer emb]
        let tokens = tokenize llm "</s>"
        length tokens `shouldBe` 1

      it "handles empty input" $ do
        let vocab = defaultVocab
        emb <- newEmbeddings vocab
        let llm = newLLM vocab [SomeLayer emb]
        let tokens = tokenize llm ""
        tokens `shouldBe` []

    describe "detokenization" $ do
      it "converts token IDs back to text" $ do
        let vocab = newVocab ["hello", "world"]
        emb <- newEmbeddings vocab
        let llm = newLLM vocab [SomeLayer emb]
        let text = detokenize llm [0, 1]
        text `shouldBe` "hello world"

      it "stops at </s> token" $ do
        let vocab = newVocab ["hello", "world", "</s>", "after"]
        emb <- newEmbeddings vocab
        let llm = newLLM vocab [SomeLayer emb]
        let text = detokenize llm [0, 1, 2, 3]
        text `shouldBe` "hello world"

    describe "softmax" $ do
      it "converts logits to probabilities" $ do
        let logits = (2 >< 3) [1.0, 2.0, 3.0, 0.5, 1.5, 2.5]
        let probs = softmax logits
        LA.rows probs `shouldBe` 2
        LA.cols probs `shouldBe` 3

      it "probabilities sum to 1 for each row" $ do
        let logits = (2 >< 3) [1.0, 2.0, 3.0, 0.5, 1.5, 2.5]
        let probs = softmax logits
        let rows' = LA.toRows probs
        let sums = map (sum . LA.toList) rows'
        all (\s -> abs (s - 1.0) < 1e-5) sums `shouldBe` True

    describe "greedyDecode" $ do
      it "selects token with highest probability" $ do
        let probs = (2 >< 3) [0.1, 0.2, 0.7, 0.6, 0.3, 0.1]
        let decoded = greedyDecode probs
        decoded `shouldBe` [2, 0]

    describe "forward pass" $ do
      it "handles empty input" $ do
        let vocab = defaultVocab
        emb <- newEmbeddings vocab
        let llm = newLLM vocab [SomeLayer emb]
        let (llm', output) = forwardLLM llm []
        LA.rows output `shouldBe` 1
        LA.cols output `shouldBe` vocabSize vocab

      it "processes token IDs through network" $ do
        let vocab = defaultVocab
        emb <- newEmbeddings vocab
        outProj <- newOutputProjection embeddingDim (vocabSize vocab)
        let llm = newLLM vocab [SomeLayer emb, SomeLayer outProj]
        let (llm', output) = forwardLLM llm [0, 1, 2]
        LA.rows output `shouldSatisfy` (> 0)
        LA.cols output `shouldBe` vocabSize vocab

    describe "predict" $ do
      it "generates non-empty output for valid input" $ do
        let vocab = defaultVocab
        emb <- newEmbeddings vocab
        outProj <- newOutputProjection embeddingDim (vocabSize vocab)
        let llm = newLLM vocab [SomeLayer emb, SomeLayer outProj]
        let output = predict llm "hello"
        output `shouldSatisfy` (not . null)

      it "handles empty input" $ do
        let vocab = defaultVocab
        emb <- newEmbeddings vocab
        let llm = newLLM vocab [SomeLayer emb]
        let output = predict llm ""
        output `shouldBe` ""

    describe "crossEntropyLoss" $ do
      it "computes loss for predictions and targets" $ do
        let probs = (2 >< 3) [0.7, 0.2, 0.1, 0.1, 0.8, 0.1]
        let targets = [0, 1]
        let loss = crossEntropyLoss probs targets
        loss `shouldSatisfy` (> 0)

      it "handles numerical stability" $ do
        let probs = (2 >< 3) [1.0, 0.0, 0.0, 0.0, 1.0, 0.0]
        let targets = [0, 1]
        let loss = crossEntropyLoss probs targets
        loss `shouldSatisfy` (>= 0)

    describe "computeGradients" $ do
      it "computes gradients with correct shape" $ do
        let probs = (2 >< 3) [0.7, 0.2, 0.1, 0.1, 0.8, 0.1]
        let targets = [0, 1]
        let grads = computeGradients probs targets
        LA.rows grads `shouldBe` 2
        LA.cols grads `shouldBe` 3

    describe "trainStep" $ do
      it "performs single training step" $ do
        let vocab = defaultVocab
        emb <- newEmbeddings vocab
        outProj <- newOutputProjection embeddingDim (vocabSize vocab)
        let llm = newLLM vocab [SomeLayer emb, SomeLayer outProj]
        let (llm', loss) = trainStep llm "hello world" 0.001
        loss `shouldSatisfy` (>= 0)

      it "handles empty text" $ do
        let vocab = defaultVocab
        emb <- newEmbeddings vocab
        let llm = newLLM vocab [SomeLayer emb]
        let (llm', loss) = trainStep llm "" 0.001
        loss `shouldBe` 0.0

    describe "train" $ do
      it "trains for multiple epochs" $ do
        let vocab = defaultVocab
        emb <- newEmbeddings vocab
        outProj <- newOutputProjection embeddingDim (vocabSize vocab)
        let llm = newLLM vocab [SomeLayer emb, SomeLayer outProj]
        let texts = ["hello", "world"]
        llm' <- train llm texts 2 0.001
        -- Just verify it completes without error
        totalParameters llm' `shouldBe` totalParameters llm

    describe "integration" $ do
      it "integrates all components in full pipeline" $ do
        let vocab = defaultVocab
        emb <- newEmbeddings vocab
        transformer <- newTransformerBlock embeddingDim hiddenDim
        outProj <- newOutputProjection embeddingDim (vocabSize vocab)
        let llm = newLLM vocab [SomeLayer emb, SomeLayer transformer, SomeLayer outProj]

        -- Test forward pass
        let (llm', output) = forwardLLM llm [0, 1, 2]
        LA.rows output `shouldSatisfy` (> 0)

        -- Test prediction
        let prediction = predict llm "hello"
        prediction `shouldSatisfy` (not . null)

        -- Test parameter counting
        let params = totalParameters llm
        params `shouldSatisfy` (> 0)

