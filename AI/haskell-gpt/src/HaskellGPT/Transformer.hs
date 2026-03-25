{-# LANGUAGE BangPatterns #-}

module HaskellGPT.Transformer
    ( TransformerBlock (..)
    , newTransformerBlock
    ) where

import           HaskellGPT.FeedForward   (FeedForward, newFeedForward)
import           HaskellGPT.LayerNorm     (LayerNorm, newLayerNorm)
import           HaskellGPT.SelfAttention (SelfAttention, newSelfAttention)
import           HaskellGPT.Types         (Layer (..))

data TransformerBlock = TransformerBlock { tbAttention   :: !SelfAttention
                                         , tbFeedForward :: !FeedForward
                                         , tbNorm1       :: !LayerNorm
                                         , tbNorm2       :: !LayerNorm
                                         }
     deriving (Show)

newTransformerBlock :: Int -> Int -> IO TransformerBlock
newTransformerBlock embDim hidDim = do
  attention <- newSelfAttention embDim
  feedForward <- newFeedForward embDim hidDim
  let norm1 = newLayerNorm embDim
  let norm2 = newLayerNorm embDim

  return TransformerBlock
    { tbAttention = attention
    , tbFeedForward = feedForward
    , tbNorm1 = norm1
    , tbNorm2 = norm2
    }

instance Layer TransformerBlock where
  forward tb input =
    let (attention', attnOutput) = forward (tbAttention tb) input
        attnResidual = input + attnOutput
        (norm1', norm1Output) = forward (tbNorm1 tb) attnResidual
        (feedForward', ffOutput) = forward (tbFeedForward tb) norm1Output
        ffResidual = norm1Output + ffOutput
        (norm2', output) = forward (tbNorm2 tb) ffResidual
        tb' = tb
          { tbAttention = attention'
          , tbFeedForward = feedForward'
          , tbNorm1 = norm1'
          , tbNorm2 = norm2'
          }
    in (tb', output)

  backward tb grads lr =
    let (norm2', gradsAfterNorm2) = backward (tbNorm2 tb) grads lr
        gradsForFF = gradsAfterNorm2
        gradsForNorm1 = gradsAfterNorm2
        (feedForward', gradsAfterFF) = backward (tbFeedForward tb) gradsForFF lr
        gradsBeforeNorm1 = gradsForNorm1 + gradsAfterFF
        (norm1', gradsAfterNorm1) = backward (tbNorm1 tb) gradsBeforeNorm1 lr
        gradsForAttn = gradsAfterNorm1
        gradsForInput = gradsAfterNorm1
        (attention', gradsAfterAttn) = backward (tbAttention tb) gradsForAttn lr
        inputGrads = gradsForInput + gradsAfterAttn
        tb' = tb
          { tbAttention = attention'
          , tbFeedForward = feedForward'
          , tbNorm1 = norm1'
          , tbNorm2 = norm2'
          }
    in (tb', inputGrads)

  layerType _ = "TransformerBlock"

  parameters tb =
    parameters (tbAttention tb) +
    parameters (tbFeedForward tb) +
    parameters (tbNorm1 tb) +
    parameters (tbNorm2 tb)
