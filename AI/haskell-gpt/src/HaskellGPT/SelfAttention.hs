{-# LANGUAGE BangPatterns #-}

module HaskellGPT.SelfAttention
    ( SelfAttention (..)
    , attention
    , computeQKV
    , newSelfAttention
    , softmax
    , softmaxBackward
    ) where

import           HaskellGPT.Adam       (Adam, initAdam, stepAdam)
import           HaskellGPT.Types      (Layer (..), Matrix, xavierInit)

import           Numeric.LinearAlgebra (cols, scale, tr)
import qualified Numeric.LinearAlgebra as LA

-- | Self-Attention mechanism data structure
-- Implements scaled dot-product attention: softmax(Q·K^T / sqrt(d_k))·V
data SelfAttention = SelfAttention { saEmbeddingDim :: !Int
                                     -- ^ Embedding dimension
                                   , saWq :: !(Matrix Float)
                                     -- ^ Query weight matrix (embedding_dim x embedding_dim)
                                   , saWk :: !(Matrix Float)
                                     -- ^ Key weight matrix (embedding_dim x embedding_dim)
                                   , saWv :: !(Matrix Float)
                                     -- ^ Value weight matrix (embedding_dim x embedding_dim)
                                   , saCachedInput :: !(Maybe (Matrix Float))
                                     -- ^ Cached input for backward pass
                                   , saCachedQ :: !(Maybe (Matrix Float))
                                     -- ^ Cached query matrix for backward pass
                                   , saCachedK :: !(Maybe (Matrix Float))
                                     -- ^ Cached key matrix for backward pass
                                   , saCachedV :: !(Maybe (Matrix Float))
                                     -- ^ Cached value matrix for backward pass
                                   , saCachedAttnScores :: !(Maybe (Matrix Float))
                                     -- ^ Cached attention scores for backward pass
                                   , saOptimizerWq :: !Adam
                                     -- ^ Optimizer for Wq
                                   , saOptimizerWk :: !Adam
                                     -- ^ Optimizer for Wk
                                   , saOptimizerWv :: !Adam
                                     -- ^ Optimizer for Wv
                                   }
     deriving (Show)

-- | Initialize self-attention with random weight initialization
-- Creates weight matrices for query, key, and value projections
-- All matrices are of shape (embedding_dim x embedding_dim)
--
-- >>> sa <- newSelfAttention 128
-- >>> saEmbeddingDim sa
-- 128
newSelfAttention :: Int -> IO SelfAttention
newSelfAttention embDim = do
  -- Initialize weight matrices with Xavier initialization
  wq <- xavierInit embDim embDim
  wk <- xavierInit embDim embDim
  wv <- xavierInit embDim embDim

  -- Create optimizers for each weight matrix
  let optWq = initAdam (embDim, embDim)
  let optWk = initAdam (embDim, embDim)
  let optWv = initAdam (embDim, embDim)

  return SelfAttention
    { saEmbeddingDim = embDim
    , saWq = wq
    , saWk = wk
    , saWv = wv
    , saCachedInput = Nothing
    , saCachedQ = Nothing
    , saCachedK = Nothing
    , saCachedV = Nothing
    , saCachedAttnScores = Nothing
    , saOptimizerWq = optWq
    , saOptimizerWk = optWk
    , saOptimizerWv = optWv
    }

-- | Compute query, key, and value matrices
-- Q = input · Wq
-- K = input · Wk
-- V = input · Wv
--
-- >>> sa <- newSelfAttention 128
-- >>> let input = konst 1.0 (10, 128)  -- 10 tokens, 128 dimensions
-- >>> let (q, k, v) = computeQKV sa input
-- >>> rows q
-- 10
-- >>> cols q
-- 128
computeQKV :: SelfAttention -> Matrix Float -> (Matrix Float, Matrix Float, Matrix Float)
computeQKV sa input =
  let q = input LA.<> saWq sa
      k = input LA.<> saWk sa
      v = input LA.<> saWv sa
  in (q, k, v)

-- | Softmax function for attention score normalization
-- Applies softmax to each row of the matrix
-- softmax(x_i) = exp(x_i - max(x)) / sum(exp(x_j - max(x)))
-- Subtracting max for numerical stability
--
-- >>> let m = (2 >< 3) [1, 2, 3, 4, 5, 6]
-- >>> let sm = softmax m
-- >>> rows sm
-- 2
-- >>> cols sm
-- 3
softmax :: Matrix Float -> Matrix Float
softmax m = LA.fromRows $ map softmaxRow (LA.toRows m)
  where
    softmaxRow row =
      let rowList = LA.toList row
          maxVal = maximum rowList
          -- Subtract max for numerical stability
          exps = map (\x -> exp (x - maxVal)) rowList
          sumExp = sum exps
          -- Normalize
          normalized = map (/ sumExp) exps
      in LA.fromList normalized

-- | Backward pass for softmax
-- Computes gradient of softmax with respect to input
-- For softmax output s and upstream gradient g:
-- grad_input = s * (g - sum(s * g))
--
-- >>> let s = softmax $ (2 >< 3) [1, 2, 3, 4, 5, 6]
-- >>> let upstreamGrad = konst 1.0 (2, 3)
-- >>> let grad = softmaxBackward s upstreamGrad
-- >>> rows grad
-- 2
-- >>> cols grad
-- 3
softmaxBackward :: Matrix Float -> Matrix Float -> Matrix Float
softmaxBackward softmaxOutput upstreamGrad =
  LA.fromRows $ zipWith computeRowGrad (LA.toRows softmaxOutput) (LA.toRows upstreamGrad)
  where
    computeRowGrad sRow gRow =
      let s = LA.toList sRow
          g = LA.toList gRow
          -- Compute sum(s * g)
          sumSG = sum $ zipWith (*) s g
          -- grad = s * (g - sum(s * g))
          grad = zipWith (\si gi -> si * (gi - sumSG)) s g
      in LA.fromList grad

-- | Attention function: softmax(Q·K^T / sqrt(d_k))·V
-- Computes scaled dot-product attention
--
-- >>> sa <- newSelfAttention 128
-- >>> let input = konst 1.0 (10, 128)
-- >>> let (q, k, v) = computeQKV sa input
-- >>> let output = attention q k v
-- >>> rows output
-- 10
-- >>> cols output
-- 128
attention :: Matrix Float -> Matrix Float -> Matrix Float -> Matrix Float
attention q k v =
  let -- Compute Q·K^T
      scores = q LA.<> tr k

      -- Scale by sqrt(d_k) for stability
      dk = fromIntegral $ cols k
      scaledScores = scale (1.0 / sqrt dk) scores

      -- Apply softmax to get attention weights
      attnWeights = softmax scaledScores

      -- Multiply by V to get output
      output = attnWeights LA.<> v
  in output

-- Layer instance for SelfAttention
instance Layer SelfAttention where
  -- Forward pass: compute attention output
  forward sa input =
    let -- Compute Q, K, V
        (q, k, v) = computeQKV sa input

        -- Compute attention scores (before softmax)
        scores = q LA.<> tr k
        dk = fromIntegral $ cols k
        scaledScores = scale (1.0 / sqrt dk) scores

        -- Apply softmax
        attnWeights = softmax scaledScores

        -- Compute output
        output = attnWeights LA.<> v

        -- Cache values for backward pass
        sa' = sa
          { saCachedInput = Just input
          , saCachedQ = Just q
          , saCachedK = Just k
          , saCachedV = Just v
          , saCachedAttnScores = Just attnWeights
          }
    in (sa', output)

  -- Backward pass: compute gradients and update weights
  backward sa grads lr =
    case (saCachedInput sa, saCachedQ sa, saCachedK sa, saCachedV sa, saCachedAttnScores sa) of
      (Just input, Just q, Just k, Just v, Just attnWeights) ->
        let dk = fromIntegral $ cols k
            scaleFactor = 1.0 / sqrt dk

            -- Gradient w.r.t. output: grads (seq_len x embedding_dim)
            -- output = attnWeights · V
            -- d_attnWeights = grads · V^T
            -- d_V = attnWeights^T · grads
            dAttnWeights = grads LA.<> tr v
            dV = tr attnWeights LA.<> grads

            -- Gradient through softmax
            -- attnWeights = softmax(scaledScores)
            dScaledScores = softmaxBackward attnWeights dAttnWeights

            -- Gradient through scaling
            dScores = scale scaleFactor dScaledScores

            -- Gradient w.r.t. Q and K
            -- scores = Q · K^T
            -- d_Q = dScores · K
            -- d_K = dScores^T · Q
            dQ = dScores LA.<> k
            dK = tr dScores LA.<> q

            -- Gradient w.r.t. weight matrices
            -- Q = input · Wq => d_Wq = input^T · d_Q
            -- K = input · Wk => d_Wk = input^T · d_K
            -- V = input · Wv => d_Wv = input^T · d_V
            dWq = tr input LA.<> dQ
            dWk = tr input LA.<> dK
            dWv = tr input LA.<> dV

            -- Update weight matrices using Adam optimizer
            (newOptWq, newWq) = stepAdam (saOptimizerWq sa) (saWq sa) dWq lr
            (newOptWk, newWk) = stepAdam (saOptimizerWk sa) (saWk sa) dWk lr
            (newOptWv, newWv) = stepAdam (saOptimizerWv sa) (saWv sa) dWv lr

            -- Gradient w.r.t. input
            -- input contributes to Q, K, V
            -- d_input = d_Q · Wq^T + d_K · Wk^T + d_V · Wv^T
            dInputFromQ = dQ LA.<> tr (saWq sa)
            dInputFromK = dK LA.<> tr (saWk sa)
            dInputFromV = dV LA.<> tr (saWv sa)
            inputGrads = dInputFromQ + dInputFromK + dInputFromV

            -- Create updated self-attention layer
            sa' = sa
              { saWq = newWq
              , saWk = newWk
              , saWv = newWv
              , saOptimizerWq = newOptWq
              , saOptimizerWk = newOptWk
              , saOptimizerWv = newOptWv
              , saCachedInput = Nothing
              , saCachedQ = Nothing
              , saCachedK = Nothing
              , saCachedV = Nothing
              , saCachedAttnScores = Nothing
              }
        in (sa', inputGrads)

      _ -> error "SelfAttention: backward called before forward"

  layerType _ = "SelfAttention"

  parameters sa =
    let embDim = saEmbeddingDim sa
        -- Three weight matrices, each of size (embedding_dim x embedding_dim)
    in 3 * embDim * embDim
