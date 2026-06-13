module Main
    ( main
    ) where

import           GiGtkApp.Domain.ButtonClick

main :: IO ()
main =
    if buttonClickedMessage == "Button clicked!"
        then putStrLn "Button click message test passed"
        else fail "Unexpected button click message"
