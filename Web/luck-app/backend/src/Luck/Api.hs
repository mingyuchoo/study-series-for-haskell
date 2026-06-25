-- | Servant API 타입 정의. 공개 라우트와 JWT 보호 라우트로 나뉜다.
module Luck.Api
  ( API
  , PublicAPI
  , ProtectedAPI
  , api
  ) where

import Data.Time (Day)
import Luck.Types
import Servant
import Servant.Auth.Server (Auth, JWT)

-- | 인증 없이 접근 가능한 라우트.
type PublicAPI =
  "auth" :> "signup" :> ReqBody '[JSON] SignupReq :> Post '[JSON] AuthResp
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

-- | 전체 API: @/api@ 하위에 공개 + 보호 라우트.
type API =
  "api"
    :> ( PublicAPI
          :<|> (Auth '[JWT] AuthUser :> ProtectedAPI)
       )

api :: Proxy API
api = Proxy
