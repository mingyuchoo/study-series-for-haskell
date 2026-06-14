module Lib
    ( module Models
    , module Services
    , module GUI
    , cliMain
    ) where

import Models
import Services
import GUI

cliMain :: IO ()
cliMain = do
    putStrLn "ThreepennyAddress - Address Book Application"
    startAddressBookGUI
