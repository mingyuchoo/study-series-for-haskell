{-# LANGUAGE BangPatterns #-}

module HaskellGPT.FeedForward
    ( FeedForward (..)
    , newFeedForward
    , relu
    , reluDerivative
    ) where

import           HaskellGPT.Adam       (Adam, initAdam, stepAdam)
import           HaskellGPT.Types      (Layer (..), Matrix, heInit)

import           Numeric.LinearAlgebra (cmap, cols, konst, rows, tr)
import qualified Numeric.LinearAlgebra as LA

-- | Feed-Forward Network data structure
-- Implements a two-layer feed-forward network with ReLU activation
-- Architecture: input -> linear -> ReLU -> linear -> output
data FeedForward = FeedForward { ffW1               :: !(Matrix Float)
                                 -- ^ First layer weights (embedding_dim x hidden_dim)
                               , ffB1               :: !(Matrix Float)
                                 -- ^ First layer bias (1 x hidden_dim)
                               , ffW2               :: !(Matrix Float)
                                 -- ^ Second layer weights (hidden_dim x embedding_dim)
                               , ffB2               :: !(Matrix Float)
                                 -- ^ Second layer bias (1 x embedding_dim)
                               , ffCachedInput      :: !(Maybe (Matrix Float))
                                 -- ^ Cached input for backward pass
                               , ffCachedHiddenPre  :: !(Maybe (Matrix Float))
                                 -- ^ Cached pre-activation hidden state
                               , ffCachedHiddenPost :: !(Maybe (Matrix Float))
                                 -- ^ Cached post-activation hidden state
                               , ffOptimizerW1      :: !Adam
                                 -- ^ Optimizer for W1
                               , ffOptimizerB1      :: !Adam
                                 -- ^ Optimizer for B1
                               , ffOptimizerW2      :: !Adam
                                 -- ^ Optimizer for W2
                               , ffOptimizerB2      :: !Adam
                                 -- ^ Optimizer for B2
                               }
     deriving (Show)

-- | Initialize feed-forward network with random weight initialization
-- Uses He initialization for weights (suitable for ReLU activation)
-- Biases are initialized to zero
--
-- Arguments:
-- - embeddingDim: Input and output dimension
-- - hiddenDim: Hidden layer dimension
--
-- >>> ff <- newFeedForward 128 256
-- >>> rows (ffW1 ff)
-- 128
-- >>> cols (ffW1 ff)
-- 256
newFeedForward :: Int -> Int -> IO FeedForward
newFeedForward embDim hidDim = do
  -- Initialize weights with He initialization (good for ReLU)
  w1 <- heInit embDim hidDim
  w2 <- heInit hidDim embDim

  -- Initialize biases to zero
  let b1 = konst 0 (1, hidDim)
  let b2 = konst 0 (1, embDim)

  -- Create optimizers for each parameter
  let optW1 = initAdam (embDim, hidDim)
  let optB1 = initAdam (1, hidDim)
  let optW2 = initAdam (hidDim, embDim)
  let optB2 = initAdam (1, embDim)

  return FeedForward
    { ffW1 = w1
    , ffB1 = b1
    , ffW2 = w2
    , ffB2 = b2
    , ffCachedInput = Nothing
    , ffCachedHiddenPre = Nothing
    , ffCachedHiddenPost = Nothing
    , ffOptimizerW1 = optW1
    , ffOptimizerB1 = optB1
    , ffOptimizerW2 = optW2
    , ffOptimizerB2 = optB2
    }

-- | ReLU activation function
-- ReLU(x) = max(0, x)
-- Applies element-wise to the matrix
--
-- >>> let m = (2 >< 3) [1, -2, 3, -4, 5, -6]
-- >>> relu m
-- (2><3)
--  [ 1.0, 0.0, 3.0
--  , 0.0, 5.0, 0.0 ]
relu :: Matrix Float -> Matrix Float
relu = cmap (\x -> max 0 x)

-- | Derivative of ReLU activation function
-- ReLU'(x) = 1 if x > 0, else 0
-- Used for backpropagation
--
-- >>> let m = (2 >< 3) [1, -2, 3, -4, 5, -6]
-- >>> reluDerivative m
-- (2><3)
--  [ 1.0, 0.0, 1.0
--  , 0.0, 1.0, 0.0 ]
reluDerivative :: Matrix Float -> Matrix Float
reluDerivative = cmap (\x -> if x > 0 then 1 else 0)

-- | Add bias to each row of the matrix
-- Broadcasts bias vector across all rows
addBias :: Matrix Float -> Matrix Float -> Matrix Float
addBias input bias =
  let nRows = rows input
      -- Repeat bias for each row
      biasRepeated = LA.fromRows $ replicate nRows (LA.flatten bias)
  in input + biasRepeated

-- Layer instance for FeedForward
instance Layer FeedForward where
  -- Forward pass: input -> linear -> ReLU -> linear -> output
  forward ff input =
    let -- First linear transformation: input · W1 + b1
        hiddenPre = (input LA.<> ffW1 ff) `addBias` ffB1 ff

        -- ReLU activation
        hiddenPost = relu hiddenPre

        -- Second linear transformation: hidden · W2 + b2
        output = (hiddenPost LA.<> ffW2 ff) `addBias` ffB2 ff

        -- Cache values for backward pass
        ff' = ff
          { ffCachedInput = Just input
          , ffCachedHiddenPre = Just hiddenPre
          , ffCachedHiddenPost = Just hiddenPost
          }
    in (ff', output)

  -- Backward pass: compute gradients and update weights
  backward ff grads lr =
    case (ffCachedInput ff, ffCachedHiddenPre ff, ffCachedHiddenPost ff) of
      (Just input, Just hiddenPre, Just hiddenPost) ->
        let -- Gradient w.r.t. output: grads (seq_len x embedding_dim)
            -- output = hiddenPost · W2 + b2

            -- Gradient w.r.t. b2: sum over batch dimension
            -- d_b2 = sum(grads, axis=0)
            dB2 = LA.asRow $ LA.fromList $ map (sum . LA.toList) $ LA.toColumns grads

            -- Gradient w.r.t. W2: hiddenPost^T · grads
            dW2 = tr hiddenPost LA.<> grads

            -- Gradient w.r.t. hiddenPost: grads · W2^T
            dHiddenPost = grads LA.<> tr (ffW2 ff)

            -- Gradient through ReLU activation
            -- d_hiddenPre = d_hiddenPost * ReLU'(hiddenPre)
            reluGrad = reluDerivative hiddenPre
            dHiddenPre = dHiddenPost * reluGrad

            -- Gradient w.r.t. b1: sum over batch dimension
            dB1 = LA.asRow $ LA.fromList $ map (sum . LA.toList) $ LA.toColumns dHiddenPre

            -- Gradient w.r.t. W1: input^T · d_hiddenPre
            dW1 = tr input LA.<> dHiddenPre

            -- Gradient w.r.t. input: d_hiddenPre · W1^T
            inputGrads = dHiddenPre LA.<> tr (ffW1 ff)

            -- Update parameters using Adam optimizer
            (newOptW1, newW1) = stepAdam (ffOptimizerW1 ff) (ffW1 ff) dW1 lr
            (newOptB1, newB1) = stepAdam (ffOptimizerB1 ff) (ffB1 ff) dB1 lr
            (newOptW2, newW2) = stepAdam (ffOptimizerW2 ff) (ffW2 ff) dW2 lr
            (newOptB2, newB2) = stepAdam (ffOptimizerB2 ff) (ffB2 ff) dB2 lr

            -- Create updated feed-forward layer
            ff' = ff
              { ffW1 = newW1
              , ffB1 = newB1
              , ffW2 = newW2
              , ffB2 = newB2
              , ffOptimizerW1 = newOptW1
              , ffOptimizerB1 = newOptB1
              , ffOptimizerW2 = newOptW2
              , ffOptimizerB2 = newOptB2
              , ffCachedInput = Nothing
              , ffCachedHiddenPre = Nothing
              , ffCachedHiddenPost = Nothing
              }
        in (ff', inputGrads)

      _ -> error "FeedForward: backward called before forward"

  layerType _ = "FeedForward"

  parameters ff =
    let embDim = cols (ffW2 ff)
        hidDim = cols (ffW1 ff)
        -- W1: embedding_dim x hidden_dim
        -- b1: 1 x hidden_dim
        -- W2: hidden_dim x embedding_dim
        -- b2: 1 x embedding_dim
    in (embDim * hidDim) + hidDim + (hidDim * embDim) + embDim
