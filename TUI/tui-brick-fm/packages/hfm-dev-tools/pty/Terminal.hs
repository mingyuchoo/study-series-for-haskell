module Terminal (Terminal, withTerminal, key, expect, quit, initialOutput) where

import           Control.Concurrent    (threadDelay)
import           Control.Exception     (IOException, bracket, bracketOnError,
                                        catch, finally, onException, throwIO)
import           Control.Monad         (unless, void)

import qualified Data.ByteString       as Bytes
import           Data.IORef            (IORef, newIORef, readIORef, writeIORef)
import qualified Data.Text             as Text
import qualified Data.Text.Encoding    as Text

import           GHC.Clock             (getMonotonicTimeNSec)
import           GHC.IO.Exception      (IOErrorType (HardwareFault))

import           System.Environment    (getEnvironment)
import           System.Exit           (ExitCode (ExitSuccess))
import           System.IO             (BufferMode (NoBuffering), Handle,
                                        hClose, hFlush, hSetBinaryMode,
                                        hSetBuffering, hWaitForInput)
import           System.IO.Error       (catchIOError, ioeGetErrorType,
                                        ioeSetLocation, isDoesNotExistError,
                                        isEOFError)
import           System.Posix.IO       (OpenMode (ReadWrite), closeFd,
                                        defaultFileFlags, dup, dupTo,
                                        fdToHandle, openFd, stdError, stdInput,
                                        stdOutput)
import           System.Posix.Process  (ProcessStatus (Exited), createSession,
                                        executeFile, forkProcess,
                                        getProcessStatus)
import           System.Posix.Signals  (sigKILL, signalProcessGroup)
import           System.Posix.Terminal (getTerminalName, openPseudoTerminal)
import           System.Posix.Types    (ProcessID)
import           System.Process        (CreateProcess (std_in),
                                        StdStream (UseHandle), createProcess,
                                        proc, waitForProcess)
import           System.Timeout        (timeout)

data Terminal = Terminal { terminalProcess :: ProcessID
                         , terminalHandle  :: Handle
                         , terminalStatus  :: IORef (Maybe ProcessStatus)
                         , initialOutput   :: Bytes.ByteString
                         }

withTerminal :: FilePath -> FilePath -> FilePath -> FilePath -> Maybe FilePath -> (Terminal -> IO a) -> IO a
withTerminal binary left right config editor = bracket acquire closeTerminal
  where
    acquire = do
      terminal <- startTerminal binary left right config editor
      output <- waitForTitle terminal `onException` closeTerminal terminal
      pure terminal {initialOutput = output}

startTerminal :: FilePath -> FilePath -> FilePath -> FilePath -> Maybe FilePath -> IO Terminal
startTerminal binary left right config editor = do
  environment <- getEnvironment
  let overrides = [("TERM", "xterm-256color"), ("XDG_CONFIG_HOME", config)] ++ maybe [] (\path -> [("VISUAL", path)]) editor
      childEnvironment = overrides ++ filter (\(name, _) -> name `notElem` map fst overrides) environment
  bracket openPseudoTerminal (\(master, slave) -> closeFd master `finally` closeFd slave) $ \(master, slave) -> do
    slaveName <- getTerminalName slave
    descriptor <- dup master
    handle <- bracketOnError (pure descriptor) closeFd fdToHandle
    flip onException (hClose handle) $ do
      hSetBinaryMode handle True
      hSetBuffering handle NoBuffering
      bracket (openFd slaveName ReadWrite defaultFileFlags >>= fdToHandle) hClose $ \slaveHandle -> do
        (_, _, _, resizeProcess) <- createProcess (proc "stty" ["rows", "24", "cols", "160"]) {std_in = UseHandle slaveHandle}
        resizeStatus <- waitForProcess resizeProcess
        unless (resizeStatus == ExitSuccess) (ioError (userError "Could not size the pseudo terminal"))
      process <- forkProcess $ do
        closeFd descriptor
        closeFd master
        void createSession
        controlling <- openFd slaveName ReadWrite defaultFileFlags
        closeFd slave
        mapM_ (dupTo controlling) [stdInput, stdOutput, stdError]
        closeFd controlling
        executeFile binary False [left, right] (Just childEnvironment)
      status <- newIORef Nothing
      pure (Terminal process handle status Bytes.empty)

pollStatus :: Terminal -> IO (Maybe ProcessStatus)
pollStatus terminal = do
  cached <- readIORef (terminalStatus terminal)
  case cached of
    Just _ -> pure cached
    Nothing -> do
      status <- getProcessStatus False False (terminalProcess terminal)
      writeIORef (terminalStatus terminal) status
      pure status

closeTerminal :: Terminal -> IO ()
closeTerminal terminal = cleanup `finally` hClose (terminalHandle terminal)
  where
    cleanup = do
      status <- pollStatus terminal
      case status of
        Nothing -> do
          catchIOError (signalProcessGroup sigKILL (terminalProcess terminal)) $ \exception ->
            unless (isDoesNotExistError exception) (ioError exception)
          void (getProcessStatus True False (terminalProcess terminal))
        Just _ -> pure ()

waitForExit :: Terminal -> IO ProcessStatus
waitForExit terminal = do
  status <- pollStatus terminal
  case status of
    Just exit -> pure exit
    Nothing   -> threadDelay 5000 >> waitForExit terminal

readOutput :: Terminal -> IO Bytes.ByteString
readOutput terminal = do
  start <- getMonotonicTimeNSec
  let loop chunks = do
        now <- getMonotonicTimeNSec
        if now - start >= 300000000 then pure (Bytes.concat (reverse chunks)) else do
          chunk <- readChunk
          if Bytes.null chunk then do
            status <- pollStatus terminal
            case status of
              Just _  -> pure (Bytes.concat (reverse chunks))
              Nothing -> loop chunks
          else loop (chunk : chunks)
      readChunk = (do
        ready <- hWaitForInput (terminalHandle terminal) 50
        if ready then Bytes.hGetSome (terminalHandle terminal) 65536 else pure Bytes.empty) `catch` ended
      ended :: IOException -> IO Bytes.ByteString
      ended exception
        | isEOFError exception || ioeGetErrorType exception == HardwareFault = do
            status <- timeout 100000 (waitForExit terminal)
            case status of
              Just _  -> pure Bytes.empty
              Nothing -> throwIO exception
        | otherwise = throwIO exception
  loop []

waitForTitle :: Terminal -> IO Bytes.ByteString
waitForTitle terminal = do
  result <- timeout 10000000 (loop Bytes.empty)
  maybe (ioError (userError "Timed out waiting for the file manager")) pure result
  where
    loop output
      | any ((`Bytes.isInfixOf` output) . encode) ["파일 관리자", "File manager"] = pure output
      | otherwise = do
          chunk <- readOutput terminal
          status <- pollStatus terminal
          case status of
            Just exit -> ioError (userError ("File manager exited during startup: " ++ show exit ++ "\n" ++ show output))
            Nothing -> loop (output <> chunk)

key :: Terminal -> String -> IO Bytes.ByteString
key terminal keys = do
  Bytes.hPut (terminalHandle terminal) (encode keys)
  hFlush (terminalHandle terminal)
  catchIOError (readOutput terminal) (\exception -> ioError (ioeSetLocation exception ("PTY read after " ++ show keys)))

expect :: Terminal -> String -> String -> IO ()
expect terminal keys expected = do
  output <- key terminal keys
  unless (encode expected `Bytes.isInfixOf` output) $
    ioError (userError ("Expected " ++ show expected ++ " after " ++ show keys ++ "\n" ++ show output))

quit :: Terminal -> IO ()
quit terminal = do
  expect terminal "\CAN" "C-x:"
  void (key terminal "\ETX")
  result <- timeout 3000000 (waitForExit terminal)
  unless (result == Just (Exited ExitSuccess)) (ioError (userError ("C-x C-c did not exit successfully: " ++ show result)))

encode :: String -> Bytes.ByteString
encode = Text.encodeUtf8 . Text.pack
