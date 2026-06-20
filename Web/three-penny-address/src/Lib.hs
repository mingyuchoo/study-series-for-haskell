module Lib
    ( module GUI
    , module Models
    , module Services
    , cliMain
    ) where

import           GUI

import           Models

import           Services

cliMain :: IO ()
cliMain = do
  putStrLn "ThreepennyAddress - Address Book Application"
  startAddressBookGUI
