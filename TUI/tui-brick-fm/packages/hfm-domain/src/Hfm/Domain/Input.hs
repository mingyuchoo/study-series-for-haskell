module Hfm.Domain.Input (Input (..), Key (..), Modifier (..), normalizeMeta) where

data Key = KChar Char | KUp | KDown | KLeft | KRight | KPageUp | KPageDown
         | KHome | KEnd | KEnter | KEsc | KBS | KDel | KFun Int
  deriving (Eq, Show)
data Modifier = MCtrl | MMeta | MAlt | MShift deriving (Eq, Show)
data Input = KeyPress Key [Modifier] | Resize Int Int | Ignored deriving (Eq, Show)

normalizeMeta :: Input -> Input
normalizeMeta (KeyPress key modifiers) = KeyPress key (map normalize modifiers)
  where
    normalize MAlt = MMeta
    normalize modifier = modifier
normalizeMeta event = event
