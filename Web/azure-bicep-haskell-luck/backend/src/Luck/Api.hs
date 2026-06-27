-- | Servant API 타입 정의. 공개 라우트와 JWT 보호 라우트로 나뉜다.
module Luck.Api
  ( API
  , PublicAPI
  , ProtectedAPI
  , api
  ) where

import Data.Text (Text)
import Data.Time (Day)
import Luck.Types.Auth (AuthResp, AuthUser, LoginReq, SignupReq, VerifyReq)
import Luck.Types.Checklist
  ( AdminCatalogItem
  , CatalogItem
  , ChecklistActiveReq
  , ChecklistCreateReq
  , ChecklistUpdateReq
  )
import Luck.Types.Common (MessageResp)
import Luck.Types.Record (RecordDTO, RecordUpdate)
import Luck.Types.User (ProfileUpdate, UserDTO)
import Servant
import Servant.Auth.Server (Auth, JWT)

-- | 인증 없이 접근 가능한 라우트.
type PublicAPI =
  "auth" :> "signup" :> "request" :> ReqBody '[JSON] SignupReq :> Post '[JSON] MessageResp
    :<|> "auth" :> "signup" :> "verify" :> ReqBody '[JSON] VerifyReq :> Post '[JSON] AuthResp
    :<|> "auth" :> "login" :> ReqBody '[JSON] LoginReq :> Post '[JSON] AuthResp
    :<|> "auth" :> "logout" :> Post '[JSON] MessageResp
    :<|> "catalog" :> Get '[JSON] [CatalogItem]

-- | JWT 인증이 필요한 라우트.
type ProtectedAPI =
  "me" :> Get '[JSON] UserDTO
    :<|> "me" :> ReqBody '[JSON] ProfileUpdate :> Put '[JSON] UserDTO
    :<|> "records"
      :> QueryParam "from" Day
      :> QueryParam "to" Day
      :> Get '[JSON] [RecordDTO]
    :<|> "records" :> Capture "date" Day :> Get '[JSON] RecordDTO
    :<|> "records" :> Capture "date" Day :> ReqBody '[JSON] RecordUpdate :> Put '[JSON] RecordDTO
    -- 관리자 전용: 체크리스트 항목 CRUD
    -- (목록은 비활성 포함 전체를 주는 별도 라우트. 공개 /catalog 는 활성 항목만.)
    :<|> "admin" :> "catalog" :> Get '[JSON] [AdminCatalogItem]
    :<|> "admin" :> "catalog" :> ReqBody '[JSON] ChecklistCreateReq :> Post '[JSON] AdminCatalogItem
    :<|> "admin" :> "catalog" :> Capture "key" Text :> ReqBody '[JSON] ChecklistUpdateReq :> Put '[JSON] AdminCatalogItem
    :<|> "admin" :> "catalog" :> Capture "key" Text :> "active" :> ReqBody '[JSON] ChecklistActiveReq :> Put '[JSON] AdminCatalogItem
    :<|> "admin" :> "catalog" :> Capture "key" Text :> Delete '[JSON] MessageResp

-- | 전체 API: @/api@ 하위에 공개 + 보호 라우트.
type API =
  "api"
    :> ( PublicAPI
           :<|> (Auth '[JWT] AuthUser :> ProtectedAPI)
       )

api :: Proxy API
api = Proxy
