module Main (main) where

import Brick (customMain)
import qualified Graphics.Vty as V
import Hfm.Application.Startup (planStartup)
import Hfm.Application.State (AppState (stTerminalSize), AppConfig (..), configWithKeyBinding)
import Hfm.Application.Effects.Runtime (runProgram)
import Hfm.Domain.Language (Language (Korean))
import Hfm.Infrastructure.Config (loadKeyBindingConfig, loadSettings, saveSettings)
import Hfm.Infrastructure.Ports (ioFileSystem, ioProcesses)
import Hfm.Tui.App (app, buildVtyFromTty)
import Hfm.Tui.I18n (renderFileError)
import qualified Data.Text as T
import System.Directory (getCurrentDirectory)
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
    _ -> die "사용법: hfm [왼쪽_디렉터리] [오른쪽_디렉터리]"
  bindings <- configWithKeyBinding <$> loadKeyBindingConfig
  settingsResult <- loadSettings
  settings <- either (die . ("설정을 읽을 수 없습니다: " ++) . T.unpack . renderFileError Korean) pure settingsResult
  let config = bindings { configSettings = settings }
  -- Validate directories before acquiring the terminal.
  result <- runProgram ioFileSystem ioProcesses (planStartup leftArg rightArg config (0, 0))
  case result of
    Left err -> die ("디렉터리를 열 수 없습니다: " ++ T.unpack (renderFileError Korean err))
    Right state -> do
      vty <- buildVtyFromTty
      size <- V.displayBounds (V.outputIface vty)
      _ <- customMain vty buildVtyFromTty Nothing (app ioFileSystem ioProcesses saveSettings)
        (state { stTerminalSize = size })
      pure ()
