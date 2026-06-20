{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE OverloadedStrings #-}

module Config
    ( KeyBindingConfig (..)
    , KeyBindingStyle (..)
    , defaultKeyBindingConfig
    , getConfigPath
    , loadKeyBindingConfig
    ) where

import           Data.Text        (Text)
import qualified Data.Text        as T
import           Data.Yaml        (FromJSON (..), decodeFileEither, withObject,
                                   (.!=), (.:?))

import           Flow             ((<|))

import           GHC.Generics     (Generic)

import           System.Directory (XdgDirectory (..), doesFileExist,
                                   getXdgDirectory)
import           System.FilePath  ((</>))

-- | 키바인딩 스타일을 나타내는 타입
-- Emacs 또는 Vim 스타일의 키바인딩을 선택할 수 있음
data KeyBindingStyle = Emacs | Vim
     deriving (Eq, Generic, Show)

-- | KeyBindingStyle의 JSON 파싱을 위한 타입클래스 인스턴스
-- 텍스트 값을 파싱하여 Vim 또는 Emacs로 변환
instance FromJSON KeyBindingStyle where
  parseJSON v = parseBindingStyle <$> parseJSON v

-- | 텍스트를 KeyBindingStyle로 변환하는 함수 (Pure)
-- "vim" 또는 "vi"는 Vim으로, 그 외는 Emacs로 변환
parseBindingStyle :: Text -> KeyBindingStyle
parseBindingStyle t = case T.toLower t of
  "vim" -> Vim
  "vi"  -> Vim
  _     -> Emacs

-- | 키바인딩 설정을 담는 레코드 타입
-- bindingStyle 필드로 키바인딩 스타일을 저장
data KeyBindingConfig = KeyBindingConfig { bindingStyle :: KeyBindingStyle
                                         }
     deriving (Eq, Generic, Show)

-- | YAML 파싱을 위한 중간 타입
-- 원시 텍스트 형태로 설정값을 저장
data RawConfig = RawConfig { rawBindingStyle :: Text
                           }
     deriving (Generic, Show)

-- | RawConfig의 JSON 파싱을 위한 타입클래스 인스턴스
-- "binding_style" 키가 없으면 기본값 "emacs" 사용
instance FromJSON RawConfig where
  parseJSON =
    withObject "RawConfig" <| \v ->
      RawConfig <$> v .:? "binding_style" .!= "emacs"

-- | 기본 키바인딩 설정값 (Pure)
-- Emacs 스타일을 기본값으로 사용
defaultKeyBindingConfig :: KeyBindingConfig
defaultKeyBindingConfig =
  KeyBindingConfig
    { bindingStyle = Emacs
    }

-- | XDG 설정 디렉토리에서 설정 파일 경로를 반환 (Effect)
-- ~/.config/fzh/keybindings.yaml 경로를 반환
getConfigPath :: IO FilePath
getConfigPath = do
  xdgConfig <- getXdgDirectory XdgConfig "fzh"
  return <| xdgConfig </> "keybindings.yaml"

-- | 설정 파일을 로드하여 KeyBindingConfig를 반환 (Effect)
-- 파일이 없거나 파싱 실패 시 기본 설정 반환
loadKeyBindingConfig :: IO KeyBindingConfig
loadKeyBindingConfig = do
  configPath <- getConfigPath
  exists <- doesFileExist configPath
  if exists
    then do
      result <- decodeFileEither configPath
      case result of
        Right raw ->
          return <|
            KeyBindingConfig
              { bindingStyle = parseBindingStyle (rawBindingStyle raw)
              }
        Left _ -> return defaultKeyBindingConfig
    else return defaultKeyBindingConfig
