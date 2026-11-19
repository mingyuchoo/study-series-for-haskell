module Runtime (workflowPorts, runTerminal) where

import Brick (customMain)
import Config (loadConfiguration)
import Control.Exception (IOException, bracket, try)
import Control.Monad (void)
import Data.Text qualified as T
import Data.Text.IO qualified as TIO
import FileSearch (listFilesRecursive)
import Fzh.Application.Ports (WorkflowPorts (..))
import Fzh.Application.Workflow (InputSource (..), Outcome (..))
import Fzh.Domain.Config (KeyBindingConfig)
import Fzh.Domain.Session (Session)
import Graphics.Vty qualified as V
import Lib (app, buildVtyFromTty)
import System.IO (hIsTerminalDevice, hPutStrLn, stderr, stdin)
import Types (configWithKeyBinding, initialState, stSession)

workflowPorts :: WorkflowPorts IO
workflowPorts =
  WorkflowPorts
    { detectSource = attempt $ do
        terminal <- hIsTerminalDevice stdin
        pure (if terminal then FileSystem "." else StandardInput)
    , gatherInput = \source -> attempt $ case source of
        FileSystem root -> listFilesRecursive root
        StandardInput -> map T.unpack . T.lines <$> TIO.getContents
    , readConfiguration = loadConfiguration
    , launchSession = \items config -> attempt (runTerminal items config)
    , writeOutput = \outcome -> attempt $ case outcome of
        NoInput -> putStrLn "No input provided"
        Selection Nothing -> pure ()
        Selection (Just item) -> putStrLn item
    , reportWarning = hPutStrLn stderr
    }

attempt :: IO a -> IO (Either String a)
attempt operation = either (Left . show @IOException) Right <$> try operation

runTerminal :: [String] -> KeyBindingConfig -> IO Session
runTerminal items config = bracket buildVtyFromTty (void . V.shutdown) $ \terminal -> do
  size <- V.displayBounds (V.outputIface terminal)
  let state = initialState (map T.pack items) (configWithKeyBinding config) size
  stSession <$> customMain terminal buildVtyFromTty Nothing app state
