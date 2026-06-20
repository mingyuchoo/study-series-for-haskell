{-# LANGUAGE TemplateHaskell #-}

module App.Model
  ( AppModel
  , clickCount
  , increaseClickCount
  , initialModel
  ) where

import Control.Lens (makeLenses)

newtype AppModel = AppModel { _clickCount :: Int }
  deriving (Eq, Show)

makeLenses ''AppModel

initialModel :: AppModel
initialModel = AppModel 0

increaseClickCount :: AppModel -> AppModel
increaseClickCount (AppModel count) = AppModel (count + 1)
