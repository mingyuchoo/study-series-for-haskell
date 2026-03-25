{-# LANGUAGE ExistentialQuantification #-}

module HaskellGPT.Types
    ( Layer (..)
    , Matrix
    , SomeLayer (..)
    , clipGradients
    , embeddingDim
    , heInit
    , hiddenDim
    , l2Norm
    , maxSeqLen
    , randomMatrix
    , xavierInit
    ) where

import           Numeric.LinearAlgebra (Matrix, cmap, sumElements, (><))
import qualified Numeric.LinearAlgebra as LA

import           System.Random         (newStdGen, randomRs)

-- Model hyperparameters
maxSeqLen :: Int
maxSeqLen = 80

embeddingDim :: Int
embeddingDim = 128

hiddenDim :: Int
hiddenDim = 256

-- Layer type class for neural network layers
class Layer l where
  -- Forward pass: input -> (updated layer with cache, output)
  forward :: l -> Matrix Float -> (l, Matrix Float)

  -- Backward pass: gradients -> learning rate -> (updated layer, input gradients)
  backward :: l -> Matrix Float -> Float -> (l, Matrix Float)

  -- Get layer type name for debugging
  layerType :: l -> String

  -- Count trainable parameters
  parameters :: l -> Int

-- Existential type wrapper for heterogeneous layer lists
data SomeLayer = forall l. Layer l => SomeLayer l

instance Layer SomeLayer where
  forward (SomeLayer l) input =
    let (l', output) = forward l input
    in (SomeLayer l', output)

  backward (SomeLayer l) grads lr =
    let (l', inputGrads) = backward l grads lr
    in (SomeLayer l', inputGrads)

  layerType (SomeLayer l) = layerType l

  parameters (SomeLayer l) = parameters l

-- Helper functions for matrix operations

-- | Generate a random matrix with values in range [-scaleVal, scaleVal]
randomMatrix :: Int -> Int -> Float -> IO (Matrix Float)
randomMatrix nRows nCols scaleVal = do
  gen <- newStdGen
  let values = take (nRows * nCols) $ randomRs (-scaleVal, scaleVal) gen
  return $ (nRows >< nCols) values

-- | Xavier initialization for weights
-- Scale: sqrt(2.0 / (rows + cols))
xavierInit :: Int -> Int -> IO (Matrix Float)
xavierInit nRows nCols = do
  let scaleVal = sqrt (2.0 / fromIntegral (nRows + nCols))
  randomMatrix nRows nCols scaleVal

-- | He initialization for ReLU layers
-- Scale: sqrt(2.0 / rows)
heInit :: Int -> Int -> IO (Matrix Float)
heInit nRows nCols = do
  let scaleVal = sqrt (2.0 / fromIntegral nRows)
  randomMatrix nRows nCols scaleVal

-- | Calculate L2 norm of a matrix
l2Norm :: Matrix Float -> Float
l2Norm m = sqrt $ sumElements $ cmap (** 2) m

-- | Clip gradients to maximum L2 norm
clipGradients :: Matrix Float -> Float -> Matrix Float
clipGradients grads maxNorm =
  let norm = l2Norm grads
  in if norm > maxNorm
     then LA.scale (maxNorm / norm) grads
     else grads
