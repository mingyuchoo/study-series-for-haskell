module Vty
    ( buildVtyFromTty
    ) where

import           Data.Maybe                          (fromMaybe)

import qualified Graphics.Vty                        as V
import           Graphics.Vty.Platform.Unix          (mkVtyWithSettings)
import qualified Graphics.Vty.Platform.Unix.Settings as VtyUnixSettings

import           System.Environment                  (lookupEnv)
import           System.Posix.IO                     (OpenMode (..),
                                                      defaultFileFlags, openFd)

-- | /dev/tty를 사용하는 커스텀 Vty 빌더 (Effect)
-- stdin이 파이프일 때도 터미널 입출력을 위해 /dev/tty 직접 사용
-- 파일 디스크립터를 열고 Vty 설정을 구성하여 Vty 인스턴스 생성
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
