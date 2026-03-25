{-# LANGUAGE BangPatterns #-}

module HaskellGPT.OutputProjection
    ( OutputProjection (..)
    , newOutputProjection
    ) where

import           HaskellGPT.Adam       (Adam, initAdam, stepAdam)
import           HaskellGPT.Types      (Layer (..), Matrix, xavierInit)

import           Numeric.LinearAlgebra (cols, konst, rows, tr)
import qualified Numeric.LinearAlgebra as LA

-- | Output Projection layer data structure
-- Projects hidden states to vocabulary logits
-- Formula: output = input · W_out + b_out
data OutputProjection = OutputProjection { opWOut :: !(Matrix Float)
                                           -- ^ Weight matrix (embedding_dim x vocab_size)
                                         , opBOut :: !(Matrix Float)
                                           -- ^ Bias vector (1 x vocab_size)
                                         , opCachedInput :: !(Maybe (Matrix Float))
                                           -- ^ Cached input for backward pass
                                         , opOptimizerW :: !Adam
                                           -- ^ Optimizer for weight matrix
                                         , opOptimizerB :: !Adam
                                           -- ^ Optimizer for bias vector
                                         }

-- | Initialize output projection layer with random weight initialization
newOutputProjection :: Int -> Int -> IO OutputProjection
newOutputProjection embDim vocabSize = do
  wOut <- xavierInit embDim vocabSize
  let bOut = konst 0 (1, vocabSize)
  return OutputProjection
    { opWOut = wOut
    , opBOut = bOut
    , opCachedInput = Nothing
    , opOptimizerW = initAdam (embDim, vocabSize)
    , opOptimizerB = initAdam (1, vocabSize)
    }

-- Layer instance for OutputProjection
instance Layer OutputProjection where
  forward op input =
    let wOut = opWOut op
        bOut = opBOut op
        logits = input LA.<> wOut
        nRows = rows logits
        bOutRepeated = LA.fromRows $ replicate nRows (LA.flatten bOut)
        output = logits + bOutRepeated
        op' = op { opCachedInput = Just input }
    in (op', output)

  backward op grads lr =
    case opCachedInput op of
      Just input ->
        let wOut = opWOut op
            bOut = opBOut op
            dWOut = tr input LA.<> grads
            dBOut = LA.asRow $ LA.fromList $ map (sum . LA.toList) $ LA.toColumns grads
            inputGrads = grads LA.<> tr wOut
            (newOptW, newWOut) = stepAdam (opOptimizerW op) wOut dWOut lr
            (newOptB, newBOut) = stepAdam (opOptimizerB op) bOut dBOut lr
            op' = op
              { opWOut = newWOut
              , opBOut = newBOut
              , opOptimizerW = newOptW
              , opOptimizerB = newOptB
              , opCachedInput = Nothing
              }
        in (op', inputGrads)
      Nothing -> error "OutputProjection: backward called before forward"

  layerType _ = "OutputProjection"

  parameters op =
    let embDim = rows (opWOut op)
        vocabSize = cols (opWOut op)
    in embDim * vocabSize + vocabSize
