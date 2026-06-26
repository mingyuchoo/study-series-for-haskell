{-# LANGUAGE DeriveAnyClass #-}

-- | 여러 기능이 공유하는 작은 타입과 JSON 인코딩 헬퍼.
module Luck.Types.Common
    ( MessageResp (..)
    , jsonOpts
    ) where

import           Data.Aeson
import           Data.Char    (toLower)
import           Data.Text    (Text)
import           GHC.Generics (Generic)

-- | 레코드 필드의 접두사를 떼고 camelCase JSON 키로 변환하는 옵션.
--   각 기능 타입 모듈이 공유한다 (예: @jsonOpts "ud"@ → "ud" 접두사 제거).
jsonOpts :: String -> Options
jsonOpts prefix =
  defaultOptions
    { fieldLabelModifier = lowerFirst . drop (length prefix)
    , omitNothingFields = True
    }
  where
    lowerFirst []       = []
    lowerFirst (c : cs) = toLower c : cs

-- | 단순 메시지 응답.
newtype MessageResp = MessageResp {message :: Text}
  deriving stock (Show, Generic)
  deriving anyclass (ToJSON, FromJSON)
