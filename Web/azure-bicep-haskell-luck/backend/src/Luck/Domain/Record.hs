-- | 기록 도메인 엔티티. 저장소(Repository)가 반환하고 웹 계층이 DTO로 변환한다.
--   익명 튜플 대신 이름 있는 필드로 경계를 명확히 한다.
module Luck.Domain.Record
    ( DailyRecord (..)
    ) where

import           Data.Text (Text)
import           Data.Time (Day)

-- | 하루치 체크리스트 기록 (도메인 표현).
data DailyRecord = DailyRecord
  { drDate      :: Day
  , drCompleted :: [Text]
  , drNote      :: Maybe Text
  }
  deriving stock (Show, Eq)
