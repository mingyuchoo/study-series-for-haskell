-- | 웹 경계 어댑터: 내부 표현(UserRow, DailyRecord)을 외부 DTO로 변환한다.
--   저장소가 DTO를 모르도록 변환 책임을 여기로 모은다.
module Luck.Web.Dto
    ( recordToDTO
    , userRowToDTO
    ) where

import           Luck.Domain.Checklist (sanitize, total)
import           Luck.Domain.Record    (DailyRecord (..))
import           Luck.Repository.User  (UserRow (..))
import           Luck.Types            (RecordDTO (..), UserDTO (..))

-- | 내부 사용자 행을 외부 DTO로 변환 (비밀번호 해시 제거).
userRowToDTO :: UserRow -> UserDTO
userRowToDTO UserRow {..} =
  UserDTO
    { udId = urId
    , udEmail = urEmail
    , udDisplayName = urDisplayName
    , udBio = urBio
    , udTimezone = urTimezone
    , udCreatedAt = urCreatedAt
    }

-- | 도메인 기록을 DTO로 변환 (key 정리 + 전체 항목 수 부여). 3개 핸들러 공통.
recordToDTO :: DailyRecord -> RecordDTO
recordToDTO DailyRecord {..} = RecordDTO drDate (sanitize drCompleted) drNote total
