{-# LANGUAGE DataKinds     #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE TypeOperators #-}

module OrderAPI
  where

import Data.Aeson (ToJSON)
import Data.Text (Text)
import GHC.Generics
import Order
import Servant

-- JSON Response Type
data OrderResponse = OrderResponse
  { status :: Text
  , logs   :: [OrderLog]
  }
  deriving (Generic, Show)

instance ToJSON OrderLog
instance ToJSON OrderResponse
instance ToJSON OrderError

-- REST API Definition
type API = "order" :> Get '[JSON] OrderResponse
