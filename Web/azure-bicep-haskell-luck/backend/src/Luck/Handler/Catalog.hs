-- | 공개 카탈로그 핸들러: 활성 체크리스트 항목 목록.
--   인증과 무관한 공개 도메인이라 인증 핸들러에서 분리해 둔다
--   (관리자 전용 CRUD 는 'Luck.Handler.Admin').
module Luck.Handler.Catalog
    ( catalogH
    ) where

import           Luck.App                  (AppM)
import           Luck.Handler.Util         (runDB)
import           Luck.Repository.Checklist (listItems)
import           Luck.Types.Checklist      (CatalogItem)
import           Luck.Web.Dto              (checklistItemToCatalog)

-- | 활성 체크리스트 항목만 공개 카탈로그로 내려준다.
catalogH :: AppM [CatalogItem]
catalogH = map checklistItemToCatalog <$> runDB listItems
