{-# LANGUAGE BangPatterns #-}

module HaskellGPT.LLM
    ( LLM (..)
    , computeGradients
    , crossEntropyLoss
    , detokenize
    , forwardLLM
    , greedyDecode
    , networkDescription
    , newLLM
    , predict
    , softmax
    , tokenize
    , totalParameters
    , train
    , trainStep
    ) where

import           Control.Monad         (foldM)

import           Data.Char             (isAlphaNum, isPunctuation)
import           Data.List             (foldl', intercalate)
import           Data.Maybe            (fromMaybe)

import           HaskellGPT.Types      (Layer (..), Matrix, SomeLayer (..),
                                        clipGradients, maxSeqLen)
import           HaskellGPT.Vocab      (Vocab, decode, encode, vocabSize)

import           Numeric.LinearAlgebra (konst, rows, (><))
import qualified Numeric.LinearAlgebra as LA

-- | LLM data structure containing vocabulary and neural network layers
data LLM = LLM { llmVocab   :: !Vocab
                 -- ^ Vocabulary for tokenization
               , llmNetwork :: ![SomeLayer]
                 -- ^ List of neural network layers
               }

-- | Create a new LLM with vocabulary and network layers
newLLM :: Vocab -> [SomeLayer] -> LLM
newLLM vocab network = LLM
  { llmVocab = vocab
  , llmNetwork = network
  }

-- | Get a description of the network architecture
-- Returns a string listing all layer types in the network
networkDescription :: LLM -> String
networkDescription llm =
  let layerTypes = map layerType (llmNetwork llm)
      numbered = zipWith (\i t -> show (i :: Int) ++ ". " ++ t) [1..] layerTypes
  in "Network Architecture:\n" ++ intercalate "\n" numbered

-- | Count total trainable parameters in the network
totalParameters :: LLM -> Int
totalParameters llm = sum $ map parameters (llmNetwork llm)

-- | Tokenize text to token IDs
-- Splits text into words and punctuation, then converts to token IDs
-- Handles special tokens like </s>
-- Unknown words are mapped to [UNK] token
tokenize :: LLM -> String -> [Int]
tokenize llm text =
  let vocab = llmVocab llm
      -- Split text into words and punctuation
      tokens = tokenizeText text
      -- Convert each token to ID, using [UNK] for unknown words
      unkId = fromMaybe 1 $ encode vocab "[UNK]"  -- Default [UNK] is at index 1
      tokenIds = map (\token -> fromMaybe unkId $ encode vocab token) tokens
  in tokenIds

-- | Tokenize a single text string into words and punctuation
-- Splits on whitespace and treats punctuation as separate tokens
tokenizeText :: String -> [String]
tokenizeText text = concatMap splitWord (words text)

-- | Split a word into alphanumeric parts and punctuation
-- "hello," -> ["hello", ","]
-- "it's" -> ["it", "'", "s"]
splitWord :: String -> [String]
splitWord [] = []
splitWord str =
  let (alphanum, rest) = span isAlphaNum str
      (punct, remaining) = span isPunctuation rest
      result = filter (not . null) [alphanum, punct]
  in result ++ splitWord remaining

-- | Detokenize token IDs back to text
-- Converts token IDs to words and joins them with spaces
-- Handles special tokens and unknown IDs
detokenize :: LLM -> [Int] -> String
detokenize llm tokenIds =
  let vocab = llmVocab llm
      -- Convert each token ID to word
      tokens = map (\tid -> fromMaybe "[UNK]" $ decode vocab tid) tokenIds
      -- Filter out special tokens except </s> which marks end
      filtered = takeWhile (/= "</s>") tokens
      -- Join tokens with spaces
  in unwords filtered

-- | Forward pass through all layers
-- Takes token IDs as input and returns logits
-- Returns updated LLM with cached values and output logits
forwardLLM :: LLM -> [Int] -> (LLM, Matrix Float)
forwardLLM llm tokenIds =
  -- Handle empty input
  if null tokenIds
  then
    let vocabSz = vocabSize (llmVocab llm)
        emptyOutput = konst 0 (1, vocabSz)
    in (llm, emptyOutput)
  else
    let -- Truncate to max sequence length
        truncatedIds = take maxSeqLen tokenIds
        seqLen = length truncatedIds

        -- Convert token IDs to input matrix (1 x seq_len)
        input = (1 >< seqLen) (map fromIntegral truncatedIds)

        -- Pass through all layers sequentially
        (updatedLayers, output) = foldl' passLayer ([], input) (llmNetwork llm)

        -- Create updated LLM with new layer states
        llm' = llm { llmNetwork = reverse updatedLayers }
    in (llm', output)
  where
    passLayer (accLayers, currentInput) layer =
      let (layer', output) = forward layer currentInput
      in (layer' : accLayers, output)

-- | Softmax function for converting logits to probabilities
-- Applies softmax row-wise for numerical stability
softmax :: Matrix Float -> Matrix Float
softmax m = LA.fromRows $ map softmaxRow (LA.toRows m)
  where
    softmaxRow row =
      let rowList = LA.toList row
          maxVal = maximum rowList
          -- Subtract max for numerical stability
          exps = map (\x -> exp (x - maxVal)) rowList
          sumExp = sum exps
          probs = map (/ sumExp) exps
      in LA.fromList probs

-- | Greedy decoding: select token with highest probability at each position
-- Returns the token ID with maximum probability for each position in sequence
greedyDecode :: Matrix Float -> [Int]
greedyDecode probs =
  let rows' = LA.toRows probs
      -- For each row, find the index of maximum value
      maxIndices = map (maxIndex . LA.toList) rows'
  in maxIndices
  where
    maxIndex xs = snd $ maximum $ zip xs [0..]

-- | Predict function: tokenize -> forward -> greedyDecode -> detokenize
-- Takes input text and generates output text
-- Handles empty input and stops at </s> token
predict :: LLM -> String -> String
predict llm inputText
  -- Handle empty input
  | null inputText = ""
  | otherwise =
      let -- Tokenize input
          tokenIds = tokenize llm inputText
      in if null tokenIds
         then ""
         else
           let -- Forward pass
               (llm', logits) = forwardLLM llm tokenIds

               -- Convert logits to probabilities
               probs = softmax logits

               -- Greedy decode to get predicted token IDs
               predictedIds = greedyDecode probs

               -- Detokenize to text
               outputText = detokenize llm' predictedIds
           in outputText

-- | Cross-entropy loss function with numerical stability
-- Computes the average cross-entropy loss between predictions and targets
-- Uses epsilon=1e-15 for numerical stability
crossEntropyLoss :: Matrix Float -> [Int] -> Float
crossEntropyLoss probs targets =
  let epsilon = 1e-15
      probRows = LA.toRows probs
      -- For each target, get the probability of the correct class
      losses = zipWith (\row target ->
        let probList = LA.toList row
            -- Ensure target is within bounds
            prob = if target >= 0 && target < length probList
                   then probList !! target
                   else epsilon
            -- Add epsilon for numerical stability
            stableProb = max prob epsilon
        in -log stableProb
        ) probRows targets
      totalLoss = sum losses
      avgLoss = totalLoss / fromIntegral (length targets)
  in avgLoss

-- | Compute gradients for softmax + cross-entropy
-- Returns gradient matrix with same shape as probabilities
-- Gradient formula: probs - one_hot(targets)
computeGradients :: Matrix Float -> [Int] -> Matrix Float
computeGradients probs targets =
  let probRows = LA.toRows probs
      -- For each row, subtract 1 from the target class probability
      gradRows = zipWith (\row target ->
        let rowList = LA.toList row
            -- Create gradient row: prob - 1 for target class, prob for others
            gradList = zipWith (\i p ->
              if i == target then p - 1.0 else p
              ) [0..] rowList
        in LA.fromList gradList
        ) probRows targets
  in LA.fromRows gradRows

-- | Train on a single example
-- Performs forward pass, computes loss, backward pass, and updates parameters
trainStep :: LLM -> String -> Float -> (LLM, Float)
trainStep llm text lr =
  -- Tokenize input text
  let tokenIds = tokenize llm text
  in if null tokenIds
     then (llm, 0.0)  -- Return unchanged if no tokens
     else
       let -- Forward pass
           (llm', logits) = forwardLLM llm tokenIds

           -- Convert logits to probabilities
           probs = softmax logits

           -- For training, we use the same tokens as targets (next token prediction)
           -- Shift targets by one position (predict next token)
           targets = if length tokenIds > 1
                     then tail tokenIds
                     else tokenIds

           -- Ensure we have matching lengths
           seqLen = min (rows probs) (length targets)
           probs' = LA.takeRows seqLen probs
           targets' = take seqLen targets

           -- Compute loss
           loss = crossEntropyLoss probs' targets'

           -- Compute gradients
           grads = computeGradients probs' targets'

           -- Clip gradients
           clippedGrads = clipGradients grads 5.0

           -- Backward pass through all layers
           (updatedLayers, _) = foldr backwardLayer ([], clippedGrads) (llmNetwork llm')

           -- Create updated LLM
           llm'' = llm' { llmNetwork = updatedLayers }
       in (llm'', loss)
  where
    backwardLayer layer (accLayers, currentGrads) =
      let (layer', inputGrads) = backward layer currentGrads lr
      in (layer' : accLayers, inputGrads)

-- | Train on dataset for multiple epochs
-- Displays training progress (epoch number and loss values)
train :: LLM -> [String] -> Int -> Float -> IO LLM
train llm texts epochs lr = do
  foldM trainEpoch llm [1..epochs]
  where
    trainEpoch model epoch = do
      putStrLn $ "Epoch " ++ show epoch ++ "/" ++ show epochs

      -- Train on all texts and accumulate losses
      (model', losses) <- foldM trainText (model, []) texts

      -- Compute average loss for this epoch
      let avgLoss = if null losses then 0.0 else sum losses / fromIntegral (length losses)
      putStrLn $ "  Average Loss: " ++ show avgLoss

      return model'

    trainText (model, losses) text = do
      let (model', loss) = trainStep model text lr
      return (model', loss : losses)

