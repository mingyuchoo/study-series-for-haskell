{-# LANGUAGE CPP #-}

module Hfm.Infrastructure.Process (editFile, runCommand) where

import Control.Exception (AsyncException (UserInterrupt), catchJust)
import Control.Monad (unless)
import qualified Data.Text as T
import System.Directory (doesFileExist)
import System.Environment (lookupEnv)
import System.Exit (ExitCode (..))
import System.Process (CreateProcess (..), proc, waitForProcess, withCreateProcess)
#if !defined(mingw32_HOST_OS)
import System.Process (shell)
#endif

editFile :: Maybe FilePath -> FilePath -> FilePath -> IO Int
editFile preferred cwd path = do
  exists <- doesFileExist path
  unless exists $ ioError (userError "편집할 일반 파일이 없습니다")
  visual <- lookupEnv "VISUAL"
  editor <- lookupEnv "EDITOR"
  let configured = filter (not . null) [value | Just value <- [preferred, visual, editor]]
#if defined(mingw32_HOST_OS)
      fallback = "notepad.exe"
#else
      fallback = "vi"
#endif
      executable = case configured of
        first : _ -> first
        [] -> fallback
  -- shortcut: editor settings name one executable; add argument parsing when editor flags are needed.
  execute cwd (proc executable [path])

runCommand :: FilePath -> T.Text -> IO Int
runCommand cwd command
  | T.null (T.strip command) || T.any (== '\0') command = ioError (userError "유효한 명령어를 입력하세요")
#if defined(mingw32_HOST_OS)
  | otherwise = execute cwd (proc "powershell.exe" ["-NoLogo", "-NoProfile", "-Command", T.unpack command])
#else
  | otherwise = execute cwd (shell (T.unpack command))
#endif

execute :: FilePath -> CreateProcess -> IO Int
execute cwd process = catchJust interrupted
  (withCreateProcess (process { cwd = Just cwd, delegate_ctlc = True }) $ \_ _ _ handle -> do
    result <- waitForProcess handle
    pure $ case result of
      ExitSuccess -> 0
      ExitFailure code -> code)
  (const (pure 130))
  where
    interrupted UserInterrupt = Just ()
    interrupted _ = Nothing
