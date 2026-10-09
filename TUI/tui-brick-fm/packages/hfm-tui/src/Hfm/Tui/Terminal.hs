{-# LANGUAGE CPP #-}

module Hfm.Tui.Terminal
    ( buildVtyFromTty
    ) where

import qualified Graphics.Vty                        as V
#if defined(mingw32_HOST_OS)
import           Graphics.Vty.Platform.Windows       (mkVty)
#else
import           Data.Maybe                          (fromMaybe)
import           Graphics.Vty.Platform.Unix          (mkVtyWithSettings)
import qualified Graphics.Vty.Platform.Unix.Settings as VtyUnixSettings

import           System.Environment                  (lookupEnv)
import           System.Posix.IO                     (OpenMode (..),
                                                      defaultFileFlags, openFd)
#endif

-- | Windows 콘솔 또는 Unix /dev/tty에서 Vty를 초기화한다.
buildVtyFromTty :: IO V.Vty
#if defined(mingw32_HOST_OS)
buildVtyFromTty = mkVty V.defaultConfig
#else
buildVtyFromTty = do
  ttyFd <- openFd "/dev/tty" ReadWrite defaultFileFlags
  termName <- fromMaybe "xterm" <$> lookupEnv "TERM"
  let unixSettings =
        VtyUnixSettings.UnixSettings
          { -- Let the input read return while Vty shuts down after C-x C-c.
            VtyUnixSettings.settingVmin = 0
          , VtyUnixSettings.settingVtime = 1
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
#endif
