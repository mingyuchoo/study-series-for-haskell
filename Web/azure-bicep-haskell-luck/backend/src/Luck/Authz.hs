-- | 인가(authorization) 횡단 관심사. 인증된 사용자의 권한을 확인한다.
--   기능 핸들러에서 권한 검사 로직을 분리해 한곳에 모은다.
module Luck.Authz
    ( requireAdmin
    ) where

import           Control.Monad.Except   (throwError)
import           Luck.App               (AppM)
import           Luck.Error             (DomainError (..))
import           Luck.Handler.Util      (runDB)
import           Luck.Repository.User   (UserRow (..), getUserById)
import           Luck.Types.Auth        (AuthUser (..))
import           Luck.Web.Error         (toServerError)

-- | 현재 인증 사용자가 관리자인지 DB에서 확인한다. 관리자가 아니면 403.
--   (JWT에 굽지 않고 매 요청마다 DB를 확인하므로 권한 회수가 즉시 반영된다.)
requireAdmin :: AuthUser -> AppM ()
requireAdmin u = do
  mrow <- runDB (\p -> getUserById p (auId u))
  case mrow of
    Just row | urIsAdmin row -> pure ()
    _ -> throwError (toServerError (Forbidden "관리자 권한이 필요합니다."))
