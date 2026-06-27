-- | 관리자 승격 정책 (순수). "누가 관리자가 되는가" 규칙을 한 곳에 모은다.
--   HTTP·DB를 모르며, 결정한 플래그를 'Luck.Repository.User.insertUser' 에 넘겨 적용한다.
module Luck.Domain.Admin
    ( AdminGrant (..)
    , adminGrant
    ) where

import           Data.Text (Text)
import qualified Data.Text as T

-- | 신규 가입자에게 관리자를 부여할지에 대한 결정.
data AdminGrant = AdminGrant
  { agExplicit          :: Bool
    -- ^ 이메일이 ADMIN_EMAILS 화이트리스트에 있음 → 무조건 관리자.
  , agFirstUserFallback :: Bool
    -- ^ ADMIN_EMAILS 미설정 시에만 켜지는 "첫 가입자=관리자" 폴백.
    --   실제 "첫 가입자" 여부(COUNT=0)는 레이스 방지를 위해 INSERT와 같은
    --   SQL 문에서 평가된다('Luck.Repository.User.insertUser').
  }

-- | ADMIN_EMAILS 목록과 가입 이메일로 승격 결정을 계산한다.
--   화이트리스트가 설정되면 폴백을 꺼, 공격자가 먼저 가입해 관리자가 되는 레이스를 막는다.
adminGrant :: [Text] -> Text -> AdminGrant
adminGrant admins email =
  AdminGrant
    { agExplicit = T.toLower email `elem` admins
    , agFirstUserFallback = null admins
    }
