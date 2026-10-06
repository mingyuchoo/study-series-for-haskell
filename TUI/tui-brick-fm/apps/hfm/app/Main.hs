module Main (main) where

import Brick (customMain)
import Hfm.Infrastructure.Config (loadKeyBindingConfig)
import Control.Exception (IOException, try)
import Hfm.Infrastructure.FileSystem (readEntries)
import qualified Graphics.Vty as V
import Hfm.Tui.App (app, buildVtyFromTty)
import Hfm.Application.State (configWithKeyBinding, initialState)
import Hfm.Infrastructure.Ports (ioFileSystem)
import System.Directory (canonicalizePath, getCurrentDirectory)
import System.Environment (getArgs)
import System.Exit (die)

main :: IO ()
main = do
  args <- getArgs
  cwd <- getCurrentDirectory
  (leftArg, rightArg) <- case args of
    [] -> pure (cwd, cwd)
    [left] -> pure (left, cwd)
    [left, right] -> pure (left, right)
    _ -> die "사용법: hfm-exe [왼쪽_디렉터리] [오른쪽_디렉터리]"
  result <- try $ do
    left <- canonicalizePath leftArg
    right <- canonicalizePath rightArg
    leftEntries <- readEntries False left
    rightEntries <- readEntries False right
    pure (left, leftEntries, right, rightEntries)
  case result of
    Left e -> die ("디렉터리를 열 수 없습니다: " ++ show (e :: IOException))
    Right (left, leftEntries, right, rightEntries) -> do
      vty <- buildVtyFromTty
      size <- V.displayBounds (V.outputIface vty)
      config <- configWithKeyBinding <$> loadKeyBindingConfig
      _ <- customMain vty buildVtyFromTty Nothing (app ioFileSystem)
        (initialState left leftEntries right rightEntries config size)
      pure ()
