{-# LANGUAGE BangPatterns #-}

module HaskellGPT.Adam
    ( Adam (..)
    , initAdam
    , stepAdam
    ) where

import           Numeric.LinearAlgebra (Matrix, add, cmap, konst, scale)

-- | Adam optimizer data structure
-- Implements adaptive moment estimation for gradient-based optimization
data Adam = Adam { adamBeta1    :: !Float
                   -- ^ Exponential decay rate for first moment (default: 0.9)
                 , adamBeta2    :: !Float
                   -- ^ Exponential decay rate for second moment (default: 0.999)
                 , adamEpsilon  :: !Float
                   -- ^ Small constant for numerical stability (default: 1e-8)
                 , adamTimestep :: !Int
                   -- ^ Current timestep counter
                 , adamM        :: !(Matrix Float)
                   -- ^ First moment estimate (mean of gradients)
                 , adamV        :: !(Matrix Float)
                   -- ^ Second moment estimate (uncentered variance of gradients)
                 }
     deriving (Show)

-- | Initialize Adam optimizer with zero-initialized momentum matrices
--
-- Creates an Adam optimizer with default hyperparameters:
-- - beta1 = 0.9 (first moment decay rate)
-- - beta2 = 0.999 (second moment decay rate)
-- - epsilon = 1e-8 (numerical stability constant)
-- - timestep = 0 (initial timestep)
-- - m and v are zero-initialized matrices of the specified shape
--
-- >>> adam <- initAdam (3, 4)
-- >>> adamTimestep adam
-- 0
initAdam :: (Int, Int) -> Adam
initAdam (nRows, nCols) = Adam
  { adamBeta1    = 0.9
  , adamBeta2    = 0.999
  , adamEpsilon  = 1e-8
  , adamTimestep = 0
  , adamM        = konst 0 (nRows, nCols)
  , adamV        = konst 0 (nRows, nCols)
  }

-- | Perform one Adam optimization step
--
-- Updates parameters using the Adam update rule:
-- 1. Increment timestep: t = t + 1
-- 2. Update biased first moment: m_t = beta1 * m_{t-1} + (1 - beta1) * grad
-- 3. Update biased second moment: v_t = beta2 * v_{t-1} + (1 - beta2) * grad^2
-- 4. Compute bias-corrected first moment: m_hat = m_t / (1 - beta1^t)
-- 5. Compute bias-corrected second moment: v_hat = v_t / (1 - beta2^t)
-- 6. Update parameters: params = params - lr * m_hat / (sqrt(v_hat) + epsilon)
--
-- Arguments:
-- - adam: Current Adam optimizer state
-- - params: Current parameter matrix
-- - grads: Gradient matrix (same shape as params)
-- - lr: Learning rate
--
-- Returns:
-- - Updated Adam optimizer state
-- - Updated parameter matrix
stepAdam :: Adam -> Matrix Float -> Matrix Float -> Float -> (Adam, Matrix Float)
stepAdam adam params grads lr =
  let -- Increment timestep
      !t = adamTimestep adam + 1

      -- Extract hyperparameters
      !beta1 = adamBeta1 adam
      !beta2 = adamBeta2 adam
      !eps = adamEpsilon adam

      -- Update biased first moment estimate
      -- m_t = beta1 * m_{t-1} + (1 - beta1) * grad
      !m = add (scale beta1 (adamM adam)) (scale (1 - beta1) grads)

      -- Update biased second moment estimate
      -- v_t = beta2 * v_{t-1} + (1 - beta2) * grad^2
      !gradSquared = cmap (** 2) grads
      !v = add (scale beta2 (adamV adam)) (scale (1 - beta2) gradSquared)

      -- Compute bias correction terms
      !beta1T = beta1 ** fromIntegral t
      !beta2T = beta2 ** fromIntegral t
      !biasCorrection1 = 1 - beta1T
      !biasCorrection2 = 1 - beta2T

      -- Compute bias-corrected first moment estimate
      -- m_hat = m_t / (1 - beta1^t)
      !mHat = scale (1 / biasCorrection1) m

      -- Compute bias-corrected second moment estimate
      -- v_hat = v_t / (1 - beta2^t)
      !vHat = scale (1 / biasCorrection2) v

      -- Compute parameter update
      -- params = params - lr * m_hat / (sqrt(v_hat) + epsilon)
      !vHatSqrt = cmap sqrt vHat
      !vHatSqrtPlusEps = cmap (+ eps) vHatSqrt
      -- Element-wise division: m_hat / (sqrt(v_hat) + epsilon)
      !denominator = vHatSqrtPlusEps
      !update = cmap (* lr) (mHat / denominator)
      !newParams = params - update

      -- Create updated Adam state
      !newAdam = adam
        { adamTimestep = t
        , adamM = m
        , adamV = v
        }
  in (newAdam, newParams)

