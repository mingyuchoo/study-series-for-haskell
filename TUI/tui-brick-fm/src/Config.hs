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
import           Data.Yaml        (FromJSON (..), decodeFileEither, withObject,
                                   (.!=), (.:?))

import           Flow             ((<|))

import           GHC.Generics     (Generic)

import           System.Directory (XdgDirectory (..), doesFileExist,
                                   getXdgDirectory)
import           System.FilePath  ((</>))

-- | 키바인딩 스타일을 나타내는 타입
-- 모든 화면에서 Emacs 스타일을 사용
data KeyBindingStyle = Emacs
     deriving (Eq, Generic, Show)

-- | KeyBindingStyle의 JSON 파싱을 위한 타입클래스 인스턴스
-- 이전 설정 파일의 스타일 값도 Emacs로 정규화
instance FromJSON KeyBindingStyle where
  parseJSON v = parseBindingStyle <$> parseJSON v

-- | 텍스트를 KeyBindingStyle로 변환하는 함수 (Pure)
-- 기존 vim/vi 설정 파일도 계속 읽되 Emacs 키바인딩으로 전환
parseBindingStyle :: Text -> KeyBindingStyle
parseBindingStyle _ = Emacs

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
-- ~/.config/hfm/keybindings.yaml 경로를 반환
getConfigPath :: IO FilePath
getConfigPath = do
  xdgConfig <- getXdgDirectory XdgConfig "hfm"
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
