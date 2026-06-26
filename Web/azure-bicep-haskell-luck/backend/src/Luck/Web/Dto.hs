-- | 웹 경계 어댑터: 내부 표현(UserRow, DailyRecord, ChecklistItem)을 외부 DTO로
--   변환한다. 저장소/도메인이 DTO를 모르도록 변환 책임을 여기로 모은다.
module Luck.Web.Dto
    ( checklistItemToAdmin
    , checklistItemToCatalog
    , recordToDTO
    , userRowToDTO
    ) where

import           Luck.Domain.Checklist (ChecklistItem (..), sanitize, total)
import           Luck.Domain.Record    (DailyRecord (..))
import           Luck.Repository.User  (UserRow (..))
import           Luck.Types.Checklist  (AdminCatalogItem (..), CatalogItem (..))
import           Luck.Types.Record     (RecordDTO (..))
import           Luck.Types.User       (UserDTO (..))

-- | 내부 사용자 행을 외부 DTO로 변환 (비밀번호 해시 제거).
userRowToDTO :: UserRow -> UserDTO
userRowToDTO UserRow {..} =
  UserDTO
    { udId = urId
    , udEmail = urEmail
    , udDisplayName = urDisplayName
    , udBio = urBio
    , udTimezone = urTimezone
    , udIsAdmin = urIsAdmin
    , udCreatedAt = urCreatedAt
    }

-- | 도메인 항목 → 공개 카탈로그 DTO (활성 여부는 노출하지 않는다).
checklistItemToCatalog :: ChecklistItem -> CatalogItem
checklistItemToCatalog ChecklistItem {..} = CatalogItem chKey chLabel

-- | 도메인 항목 → 관리자 DTO (활성 여부 포함).
checklistItemToAdmin :: ChecklistItem -> AdminCatalogItem
checklistItemToAdmin ChecklistItem {..} = AdminCatalogItem chKey chLabel chActive

-- | 도메인 기록을 DTO로 변환 (현재 카탈로그 기준 key 정리 + 전체 항목 수 부여).
--   카탈로그가 DB에 있으므로 호출 측에서 현재 항목 목록을 넘겨준다.
recordToDTO :: [ChecklistItem] -> DailyRecord -> RecordDTO
recordToDTO cat DailyRecord {..} =
  RecordDTO drDate (sanitize cat drCompleted) drNote (total cat)
