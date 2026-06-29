-- | API 라우트와 핸들러를 연결하는 얇은 조립 계층.
--   실제 로직은 기능별 'Luck.Handler.*' 모듈에 있다.
module Luck.Server
  ( server
  ) where

import Luck.Api (API, ProtectedAPI, PublicAPI)
import Luck.App (AppM)
import Luck.Handler.Admin (createItemH, deleteItemH, listItemsH, setActiveH, updateItemH)
import Luck.Handler.Auth (loginH, logoutH, signupRequestH, signupVerifyH)
import Luck.Handler.Catalog (catalogH)
import Luck.Handler.Profile (meH, updateMeH)
import Luck.Handler.Record (putRecordH, recordH, recordsH)
import Luck.Types.Auth (AuthUser)
import Luck.Web.Error (jsonErr)
import Servant
import Servant.Auth.Server (AuthResult (..), throwAll)

-- | API 전체 서버.
server :: ServerT API AppM
server = publicServer :<|> protectedServer

-- | 공개 라우트 서버.
publicServer :: ServerT PublicAPI AppM
publicServer = signupRequestH :<|> signupVerifyH :<|> loginH :<|> logoutH :<|> catalogH

-- | 보호 라우트 서버. 인증되지 않으면 모든 엔드포인트에서 401.
protectedServer :: AuthResult AuthUser -> ServerT ProtectedAPI AppM
protectedServer (Authenticated u) =
  meH u
    :<|> updateMeH u
    :<|> recordsH u
    :<|> recordH u
    :<|> putRecordH u
    :<|> listItemsH u
    :<|> createItemH u
    :<|> updateItemH u
    :<|> setActiveH u
    :<|> deleteItemH u
protectedServer _ = throwAll (jsonErr err401 "인증이 필요합니다.")
