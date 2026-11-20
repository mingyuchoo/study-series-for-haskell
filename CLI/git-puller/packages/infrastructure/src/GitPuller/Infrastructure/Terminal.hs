module GitPuller.Infrastructure.Terminal (
  Terminal (..),
  isInteractive,
  withProgress,
)
where

import Control.Exception (finally)
import Control.Monad (when)
import System.Environment (lookupEnv)
import System.IO (hFlush, hIsTerminalDevice, hPutStr, stderr)

data Terminal = Terminal
  { writeLine :: String -> IO ()
  , writeProgress :: String -> IO ()
  }

isInteractive :: IO Bool
isInteractive = do
  terminalType <- lookupEnv "TERM"
  if terminalType `elem` [Nothing, Just "", Just "dumb"]
    then pure False
    else hIsTerminalDevice stderr

emit :: String -> IO ()
emit text = hPutStr stderr text >> hFlush stderr

withProgress :: Bool -> (Terminal -> IO result) -> IO result
withProgress interactive action = do
  when interactive (emit "\ESC[2J\ESC[2;r\ESC[2;1H")
  action Terminal{writeLine = line, writeProgress = progress}
    `finally` when interactive (emit "\ESC7\ESC[r\ESC8")
 where
  line text = emit (text <> "\n")
  progress text
    | interactive = emit ("\ESC7\ESC[1;1H\ESC[2K\ESC[?7l" <> text <> "\ESC[?7h\ESC8")
    | otherwise = line text
