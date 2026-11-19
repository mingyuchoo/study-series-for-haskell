module Vty
  ( buildVtyFromTty
  ) where

import Data.Maybe (fromMaybe)

import Graphics.Vty qualified as V
import Graphics.Vty.Platform.Unix (mkVtyWithSettings)
import Graphics.Vty.Platform.Unix.Settings qualified as VtyUnixSettings

import System.Environment (lookupEnv)
import System.Posix.IO
  ( OpenMode (..)
  , defaultFileFlags
  , openFd
  )

buildVtyFromTty :: IO V.Vty
buildVtyFromTty = do
  ttyFd <- openFd "/dev/tty" ReadWrite defaultFileFlags
  termName <- fromMaybe "xterm" <$> lookupEnv "TERM"
  let unixSettings =
        VtyUnixSettings.UnixSettings
          { VtyUnixSettings.settingVmin = 1
          , VtyUnixSettings.settingVtime = 100
          , VtyUnixSettings.settingInputFd = ttyFd
          , VtyUnixSettings.settingOutputFd = ttyFd
          , VtyUnixSettings.settingTermName = termName
          }
      userConfig =
        V.VtyUserConfig
          { V.configInputMap = mempty
          , V.configPreferredColorMode = Nothing
          , V.configDebugLog = Nothing
          , V.configAllowCustomUnicodeWidthTables = Nothing
          , V.configTermWidthMaps = []
          }
  mkVtyWithSettings userConfig unixSettings
