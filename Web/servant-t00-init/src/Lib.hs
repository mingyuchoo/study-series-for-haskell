{-# LANGUAGE DataKinds       #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeOperators   #-}

module Lib
  ( app
  , startApp
  ) where

import Data.Aeson
import Data.Aeson.TH
import Data.Kind
import Data.Text
import Data.Time.Calendar

import Network.Wai
import Network.Wai.Handler.Warp

import Servant

type UserAPI1 :: *
type UserAPI1 = "users" :> Get '[JSON] [User]

type UserAPI2 :: *
type UserAPI2 =
  "users" :> Get '[JSON] [User]
    :<|> "isaac" :> Get '[JSON] User
    :<|> "albert" :> Get '[JSON] User

type User :: *
data User = User
  { name              :: String
  , age               :: Int
  , email             :: String
  , registration_date :: Day
  }
  deriving (Eq, Show)

$(deriveJSON defaultOptions ''User)

startApp :: IO ()
startApp = run 4000 app

app :: Application
app = serve userAPI server2

userAPI :: Proxy UserAPI2
userAPI = Proxy

{-- | choose server1 or server2

server1 :: Server UserAPI1
server1 = return users1

users1 :: [User]
users1 = [ User "Isaac Newton" 372 "isaac@email.com" (fromGregorian 1683  3 1)
         , User "Albert Einstein" 136 "ae@mc2.org" (fromGregorian 1905 12 1)
         ]
--}

server2 :: Server UserAPI2
server2 =
  return users2
    :<|> return isaac
    :<|> return albert

users2 :: [User]
users2 = [isaac, albert]

isaac :: User
isaac = User "Isaac Newton" 372 "isaac@email.com" (fromGregorian 1683 3 1)

albert :: User
albert = User "Albert Einstein" 136 "ae@mc2.org" (fromGregorian 1905 12 1)
