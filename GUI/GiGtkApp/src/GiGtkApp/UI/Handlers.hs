module GiGtkApp.UI.Handlers
    ( onButtonClicked
    ) where

import           GiGtkApp.Domain.ButtonClick

onButtonClicked :: IO ()
onButtonClicked = putStrLn buttonClickedMessage
