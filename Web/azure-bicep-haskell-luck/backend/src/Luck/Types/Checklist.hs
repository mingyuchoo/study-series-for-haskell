-- | 체크리스트 경계 타입 (DTO).
--
--   공개와 관리자 응답을 분리한다:
--
--     * 'CatalogItem'      — 공개 @GET /catalog@. 활성 항목만 나가므로 @key, label@ 만.
--     * 'AdminCatalogItem'  — 관리자 응답. 비활성 항목도 다루므로 @active@ 포함.
--
--   이렇게 두면 DB/관리 표현(@active@ 등)이 공개 계약에 새어 나가지 않는다.
module Luck.Types.Checklist
    ( -- * 응답 DTO
      AdminCatalogItem (..)
    , CatalogItem (..)
      -- * 관리자 요청 DTO
    , ChecklistActiveReq (..)
    , ChecklistCreateReq (..)
    , ChecklistUpdateReq (..)
    ) where

import           Data.Aeson
import           Data.Text         (Text)
import           GHC.Generics      (Generic)
import           Luck.Types.Common (jsonOpts)

-- | 공개 체크리스트 항목 (활성 항목만 노출되므로 활성 여부는 담지 않는다).
data CatalogItem = CatalogItem
  { ciKey   :: Text
  , ciLabel :: Text
  }
  deriving stock (Show, Generic)

instance ToJSON CatalogItem where
  toJSON = genericToJSON (jsonOpts "ci")

instance FromJSON CatalogItem where
  parseJSON = genericParseJSON (jsonOpts "ci")

-- | 관리자용 체크리스트 항목 (비활성 항목도 다루므로 @active@ 포함).
data AdminCatalogItem = AdminCatalogItem
  { acKey    :: Text
  , acLabel  :: Text
  , acActive :: Bool
  }
  deriving stock (Show, Generic)

instance ToJSON AdminCatalogItem where
  toJSON = genericToJSON (jsonOpts "ac")

instance FromJSON AdminCatalogItem where
  parseJSON = genericParseJSON (jsonOpts "ac")

-- | 항목 생성 요청 (관리자). @{ "label": ... }@ — key는 서버가 자동 생성.
newtype ChecklistCreateReq = ChecklistCreateReq
  { ccLabel :: Text
  }
  deriving stock (Show, Generic)

instance FromJSON ChecklistCreateReq where
  parseJSON = genericParseJSON (jsonOpts "cc")

instance ToJSON ChecklistCreateReq where
  toJSON = genericToJSON (jsonOpts "cc")

-- | 항목 수정 요청 (관리자). key는 URL에서 받고 라벨만 바꾼다.
newtype ChecklistUpdateReq = ChecklistUpdateReq
  { cuLabel :: Text
  }
  deriving stock (Show, Generic)

instance FromJSON ChecklistUpdateReq where
  parseJSON = genericParseJSON (jsonOpts "cu")

instance ToJSON ChecklistUpdateReq where
  toJSON = genericToJSON (jsonOpts "cu")

-- | 항목 활성/비활성 토글 요청 (관리자). @{ "active": true|false }@
newtype ChecklistActiveReq = ChecklistActiveReq
  { caActive :: Bool
  }
  deriving stock (Show, Generic)

instance FromJSON ChecklistActiveReq where
  parseJSON = genericParseJSON (jsonOpts "ca")

instance ToJSON ChecklistActiveReq where
  toJSON = genericToJSON (jsonOpts "ca")
