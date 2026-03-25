{-# LANGUAGE BangPatterns #-}

module HaskellGPT.LayerNorm
    ( LayerNorm (..)
    , newLayerNorm
    , normalize
    ) where

import           HaskellGPT.Adam       (Adam, initAdam, stepAdam)
import           HaskellGPT.Types      (Layer (..), Matrix)

import           Numeric.LinearAlgebra (cmap, cols, konst, rows, (><))
import qualified Numeric.LinearAlgebra as LA

-- | Layer Normalization data structure
-- Normalizes activations across the feature dimension
-- Formula: gamma * (x - mean) / (std + epsilon) + beta
data LayerNorm = LayerNorm { lnEpsilon        :: !Float
                             -- ^ Small constant for numerical stability (1e-5)
                           , lnGamma          :: !(Matrix Float)
                             -- ^ Learnable scale parameter (1 x embedding_dim)
                           , lnBeta           :: !(Matrix Float)
                             -- ^ Learnable shift parameter (1 x embedding_dim)
                           , lnCachedInput    :: !(Maybe (Matrix Float))
                             -- ^ Cached input for backward pass
                           , lnCachedMean     :: !(Maybe (Matrix Float))
                             -- ^ Cached mean for backward pass
                           , lnCachedStd      :: !(Maybe (Matrix Float))
                             -- ^ Cached standard deviation for backward pass
                           , lnOptimizerGamma :: !Adam
                             -- ^ Optimizer for gamma
                           , lnOptimizerBeta  :: !Adam
                             -- ^ Optimizer for beta
                           }
     deriving (Show)

-- | Initialize layer normalization with gamma=1 and beta=0
--
-- Arguments:
-- - embeddingDim: Dimension of the features to normalize
--
-- >>> ln <- newLayerNorm 128
-- >>> lnEpsilon ln
-- 1.0e-5
newLayerNorm :: Int -> LayerNorm
newLayerNorm embDim = LayerNorm
  { lnEpsilon = 1e-5
  , lnGamma = konst 1 (1, embDim)  -- Initialize to ones
  , lnBeta = konst 0 (1, embDim)   -- Initialize to zeros
  , lnCachedInput = Nothing
  , lnCachedMean = Nothing
  , lnCachedStd = Nothing
  , lnOptimizerGamma = initAdam (1, embDim)
  , lnOptimizerBeta = initAdam (1, embDim)
  }

-- | Compute mean of each row
rowMean :: Matrix Float -> Matrix Float
rowMean m =
  let nRows = rows m
      nCols = cols m
      means = map (\row -> sum (LA.toList row) / fromIntegral nCols) (LA.toRows m)
  in (nRows >< 1) means

-- | Compute standard deviation of each row
rowStd :: Matrix Float -> Matrix Float -> Float -> Matrix Float
rowStd m means eps =
  let nRows = rows m
      nCols = cols m
      rowsList = LA.toRows m
      meansList = LA.toList $ LA.flatten means
      stds = zipWith (\row mean ->
        let variance = sum [(x - mean) ** 2 | x <- LA.toList row] / fromIntegral nCols
        in sqrt (variance + eps)
        ) rowsList meansList
  in (nRows >< 1) stds

-- | Normalize input: gamma * (x - mean) / (std + epsilon) + beta
-- Normalizes each row independently
--
-- Arguments:
-- - ln: LayerNorm instance
-- - input: Input matrix (seq_len x embedding_dim)
--
-- Returns:
-- - Normalized output matrix
normalize :: LayerNorm -> Matrix Float -> Matrix Float
normalize ln input =
  let eps = lnEpsilon ln
      gamma = lnGamma ln
      beta = lnBeta ln

      -- Compute mean and std for each row
      means = rowMean input
      stds = rowStd input means eps

      -- Normalize: (x - mean) / std
      nRows = rows input
      normalized = LA.fromRows $ zipWith3 (\row mean std ->
        let meanVal = LA.atIndex mean 0
            stdVal = LA.atIndex std 0
        in cmap (\x -> (x - meanVal) / stdVal) row
        ) (LA.toRows input) (LA.toRows means) (LA.toRows stds)

      -- Apply learnable parameters: gamma * normalized + beta
      -- Broadcast gamma and beta across all rows
      gammaRepeated = LA.fromRows $ replicate nRows (LA.flatten gamma)
      betaRepeated = LA.fromRows $ replicate nRows (LA.flatten beta)

      output = gammaRepeated * normalized + betaRepeated
  in output

-- Layer instance for LayerNorm
instance Layer LayerNorm where
  -- Forward pass: normalize input
  forward ln input =
    let eps = lnEpsilon ln

        -- Compute mean and std for each row
        means = rowMean input
        stds = rowStd input means eps

        -- Normalize
        output = normalize ln input

        -- Cache values for backward pass
        ln' = ln
          { lnCachedInput = Just input
          , lnCachedMean = Just means
          , lnCachedStd = Just stds
          }
    in (ln', output)

  -- Backward pass: compute gradients for gamma, beta, and input
  backward ln grads lr =
    case (lnCachedInput ln, lnCachedMean ln, lnCachedStd ln) of
      (Just input, Just means, Just stds) ->
        let gamma = lnGamma ln
            nRows = rows input
            nCols = cols input

            -- Compute normalized input (x - mean) / std
            normalized = LA.fromRows $ zipWith3 (\row mean std ->
              let meanVal = LA.atIndex mean 0
                  stdVal = LA.atIndex std 0
              in cmap (\x -> (x - meanVal) / stdVal) row
              ) (LA.toRows input) (LA.toRows means) (LA.toRows stds)

            -- Gradient w.r.t. gamma: sum(grads * normalized, axis=0)
            -- d_gamma = sum over all rows of (grads * normalized)
            dGamma = LA.asRow $ LA.fromList $ map (sum . LA.toList) $ LA.toColumns (grads * normalized)

            -- Gradient w.r.t. beta: sum(grads, axis=0)
            dBeta = LA.asRow $ LA.fromList $ map (sum . LA.toList) $ LA.toColumns grads

            -- Gradient w.r.t. normalized: grads * gamma
            gammaRepeated = LA.fromRows $ replicate nRows (LA.flatten gamma)
            dNormalized = grads * gammaRepeated

            -- Gradient w.r.t. input (complex due to mean and std dependencies)
            -- For each row independently:
            -- d_input = (1/std) * (d_normalized - mean(d_normalized) - normalized * mean(d_normalized * normalized))
            inputGrads = LA.fromRows $ map (\i ->
              let dNormRow = (LA.toRows dNormalized) !! i
                  normRow = (LA.toRows normalized) !! i
                  stdVal = (LA.toRows stds) !! i
                  s = LA.atIndex stdVal 0
                  dNormList = LA.toList dNormRow
                  normList = LA.toList normRow

                  -- Mean of d_normalized for this row
                  meanDNorm = sum dNormList / fromIntegral nCols

                  -- Mean of (d_normalized * normalized) for this row
                  meanDNormNorm = sum (zipWith (*) dNormList normList) / fromIntegral nCols

                  -- Compute gradient for each element
                  dInput = zipWith (\dn n -> (1 / s) * (dn - meanDNorm - n * meanDNormNorm)) dNormList normList
              in LA.fromList dInput
              ) [0 .. nRows - 1]

            -- Update parameters using Adam optimizer
            (newOptGamma, newGamma) = stepAdam (lnOptimizerGamma ln) gamma dGamma lr
            (newOptBeta, newBeta) = stepAdam (lnOptimizerBeta ln) (lnBeta ln) dBeta lr

            -- Create updated layer normalization
            ln' = ln
              { lnGamma = newGamma
              , lnBeta = newBeta
              , lnOptimizerGamma = newOptGamma
              , lnOptimizerBeta = newOptBeta
              , lnCachedInput = Nothing
              , lnCachedMean = Nothing
              , lnCachedStd = Nothing
              }
        in (ln', inputGrads)

      _ -> error "LayerNorm: backward called before forward"

  layerType _ = "LayerNorm"

  parameters ln =
    let embDim = cols (lnGamma ln)
        -- gamma: 1 x embedding_dim
        -- beta: 1 x embedding_dim
    in embDim + embDim

