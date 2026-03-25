{-# LANGUAGE BangPatterns #-}

module HaskellGPT.Embeddings
    ( Embeddings (..)
    , embedTokens
    , initPositionalEmbeddings
    , initTokenEmbeddings
    , newEmbeddings
    ) where

import           HaskellGPT.Adam       (Adam, initAdam, stepAdam)
import           HaskellGPT.Types      (Layer (..), Matrix, embeddingDim,
                                        maxSeqLen, xavierInit)
import           HaskellGPT.Vocab      (Vocab, vocabSize)

import           Numeric.LinearAlgebra (cols, konst, rows, (><))
import qualified Numeric.LinearAlgebra as LA

-- | Embeddings layer data structure
-- Converts token IDs to dense vector representations with positional information
data Embeddings = Embeddings { embTokenEmbeddings :: !(Matrix Float)
                               -- ^ Token embedding matrix (vocab_size x embedding_dim)
                             , embPositionalEmbeddings :: !(Matrix Float)
                               -- ^ Positional embedding matrix (max_seq_len x embedding_dim)
                             , embCachedInput :: !(Maybe (Matrix Float))
                               -- ^ Cached input for backward pass
                             , embTokenOptimizer :: !Adam
                               -- ^ Optimizer for token embeddings
                             , embPositionalOptimizer :: !Adam
                               -- ^ Optimizer for positional embeddings
                             }
     deriving (Show)

-- | Initialize token embeddings with random Xavier initialization
-- Creates a matrix of shape (vocab_size, embedding_dim) with random values
-- scaled according to Xavier initialization: sqrt(2.0 / (vocab_size + embedding_dim))
--
-- >>> tokenEmb <- initTokenEmbeddings 100 128
-- >>> rows tokenEmb
-- 100
-- >>> cols tokenEmb
-- 128
initTokenEmbeddings :: Int -> Int -> IO (Matrix Float)
initTokenEmbeddings vocabSz embDim = xavierInit vocabSz embDim

-- | Initialize positional embeddings with sinusoidal pattern
-- Creates a matrix of shape (max_seq_len, embedding_dim) using sinusoidal functions
-- This allows the model to learn relative positions
--
-- For even dimensions: sin(pos / 10000^(2i/d_model))
-- For odd dimensions: cos(pos / 10000^(2i/d_model))
--
-- >>> let posEmb = initPositionalEmbeddings 80 128
-- >>> rows posEmb
-- 80
-- >>> cols posEmb
-- 128
initPositionalEmbeddings :: Int -> Int -> Matrix Float
initPositionalEmbeddings maxSeq embDim =
  let positions = [0 .. maxSeq - 1]
      dims = [0 .. embDim - 1]
      -- Compute positional encoding for a given position and dimension
      posEnc pos dim =
        let angle = fromIntegral pos / (10000 ** (fromIntegral (2 * (dim `div` 2)) / fromIntegral embDim))
        in if even dim then sin angle else cos angle
      -- Generate all values
      values = [posEnc pos dim | pos <- positions, dim <- dims]
  in (maxSeq >< embDim) values

-- | Create new embeddings layer from vocabulary
-- Initializes token embeddings randomly and positional embeddings with sinusoidal pattern
-- Also creates Adam optimizers for both embedding matrices
--
-- >>> vocab <- return defaultVocab
-- >>> emb <- newEmbeddings vocab
-- >>> rows (embTokenEmbeddings emb)
-- vocabSize vocab
newEmbeddings :: Vocab -> IO Embeddings
newEmbeddings vocab = do
  let vocabSz = vocabSize vocab
  let embDim = embeddingDim
  let maxSeq = maxSeqLen

  -- Initialize token embeddings randomly
  tokenEmb <- initTokenEmbeddings vocabSz embDim

  -- Initialize positional embeddings with sinusoidal pattern
  let posEmb = initPositionalEmbeddings maxSeq embDim

  -- Create optimizers
  let tokenOpt = initAdam (vocabSz, embDim)
  let posOpt = initAdam (maxSeq, embDim)

  return Embeddings
    { embTokenEmbeddings = tokenEmb
    , embPositionalEmbeddings = posEmb
    , embCachedInput = Nothing
    , embTokenOptimizer = tokenOpt
    , embPositionalOptimizer = posOpt
    }

-- | Retrieve embeddings for a list of token IDs
-- Returns a matrix of shape (seq_len, embedding_dim)
-- Each row corresponds to the embedding of one token
--
-- >>> emb <- newEmbeddings defaultVocab
-- >>> let tokenIds = [0, 1, 2]
-- >>> let embedded = embedTokens emb tokenIds
-- >>> rows embedded
-- 3
-- >>> cols embedded
-- 128
embedTokens :: Embeddings -> [Int] -> Matrix Float
embedTokens emb tokenIds =
  let tokenEmb = embTokenEmbeddings emb
      -- Extract embedding for each token ID
      embeddings = map (\tokenId -> LA.flatten $ tokenEmb LA.? [tokenId]) tokenIds
      -- Stack embeddings into a matrix
  in LA.fromRows embeddings

-- Layer instance for Embeddings
instance Layer Embeddings where
  -- Forward pass: token IDs -> token embeddings + positional embeddings
  forward emb input =
    let -- Input is expected to be a matrix of token IDs (batch_size x seq_len)
        -- For simplicity, we'll handle single sequence (1 x seq_len)
        -- Extract token IDs from input matrix
        tokenIds = map round $ LA.toList $ LA.flatten input
        seqLen = length tokenIds

        -- Get token embeddings
        tokenEmb = embedTokens emb tokenIds

        -- Get positional embeddings for this sequence length
        posEmb = LA.takeRows seqLen (embPositionalEmbeddings emb)

        -- Add token and positional embeddings
        output = tokenEmb + posEmb

        -- Cache input for backward pass
        emb' = emb { embCachedInput = Just input }
    in (emb', output)

  -- Backward pass: compute gradients and update token embeddings
  backward emb grads lr =
    case embCachedInput emb of
      Nothing -> error "Embeddings: backward called before forward"
      Just input ->
        let -- Extract token IDs from cached input
            tokenIds = map round $ LA.toList $ LA.flatten input
            seqLen = length tokenIds

            -- Gradients flow back to token embeddings
            -- We need to update the token embedding matrix
            -- For each token ID, accumulate the gradient
            tokenEmb = embTokenEmbeddings emb
            vocabSz = rows tokenEmb
            embDim = cols tokenEmb

            -- Create gradient matrix for token embeddings (initialized to zero)
            tokenGrads = konst 0 (vocabSz, embDim)

            -- Accumulate gradients for each token
            -- For each position in the sequence, add the gradient to the corresponding token's embedding
            tokenGrads' = foldl (\tg (idx, gradRow) ->
              if idx >= 0 && idx < vocabSz
              then
                -- Update the row corresponding to this token ID
                let rows' = LA.toRows tg
                    currentRow = rows' !! idx
                    updatedRow = currentRow + gradRow
                    -- Replace the row in the matrix
                    newRows = take idx rows' ++ [updatedRow] ++ drop (idx + 1) rows'
                in LA.fromRows newRows
              else tg
              ) tokenGrads (zip tokenIds (LA.toRows grads))

            -- Update token embeddings using Adam optimizer
            (newTokenOpt, newTokenEmb) = stepAdam (embTokenOptimizer emb) tokenEmb tokenGrads' lr

            -- Positional embeddings are typically not updated during training
            -- (they use fixed sinusoidal pattern)
            -- But we'll keep the optimizer for consistency

            -- Create updated embeddings layer
            emb' = emb
              { embTokenEmbeddings = newTokenEmb
              , embTokenOptimizer = newTokenOpt
              , embCachedInput = Nothing  -- Clear cache
              }

            -- Input gradients (not used in this layer, but required by interface)
            inputGrads = konst 0 (1, seqLen)
        in (emb', inputGrads)

  layerType _ = "Embeddings"

  parameters emb =
    let tokenEmb = embTokenEmbeddings emb
        posEmb = embPositionalEmbeddings emb
    in (rows tokenEmb * cols tokenEmb) + (rows posEmb * cols posEmb)
