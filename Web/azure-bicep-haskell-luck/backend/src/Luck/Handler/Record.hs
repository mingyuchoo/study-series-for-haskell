{-# LANGUAGE RecordWildCards #-}

-- | 일별 기록 핸들러 (기간 조회, 단일 조회, 저장).
module Luck.Handler.Record
    ( putRecordH
    , recordH
    , recordsH
    ) where

import           Control.Monad.Except      (throwError)
import           Data.Maybe                (fromMaybe)
import           Data.Time                 (Day)
import           Luck.App                  (AppM)
import           Luck.Domain.Checklist     (sanitize)
import           Luck.Domain.Record        (DailyRecord (..))
import           Luck.Error                (DomainError (..))
import           Luck.Handler.Util         (runDB)
import           Luck.Repository.Checklist (listItems)
import           Luck.Repository.Record    (getRecord, getRecordsBetween, upsertRecord)
import           Luck.Types.Auth           (AuthUser (..))
import           Luck.Types.Record         (RecordDTO, RecordUpdate (..))
import           Luck.Web.Dto              (recordToDTO)
import           Luck.Web.Error            (toServerError)

recordsH :: AuthUser -> Maybe Day -> Maybe Day -> AppM [RecordDTO]
recordsH u mFrom mTo =
  case (mFrom, mTo) of
    (Just from, Just to) -> do
      rows <- runDB (\p -> getRecordsBetween p (auId u) from to)
      toRecordDTOs rows
    _ -> throwError (toServerError (ValidationError "from, to 쿼리 파라미터가 필요합니다."))

recordH :: AuthUser -> Day -> AppM RecordDTO
recordH u d = do
  mrow <- runDB (\p -> getRecord p (auId u) d)
  toRecordDTO (fromMaybe (DailyRecord d [] Nothing) mrow)

putRecordH :: AuthUser -> Day -> RecordUpdate -> AppM RecordDTO
putRecordH u d RecordUpdate {..} = do
  cat <- runDB listItems
  saved <- runDB (\p -> upsertRecord p (auId u) d (sanitize cat ruCompleted) ruNote)
  pure (recordToDTO cat saved)

-- | 도메인 기록을 DTO 로 변환한다. 변환에는 현재 카탈로그가 필요하므로
--   카탈로그 로드를 이 한곳에 감춰, 각 핸들러가 "무엇을 조회/저장하는지"만 드러나게 한다.
toRecordDTO :: DailyRecord -> AppM RecordDTO
toRecordDTO r = do
  cat <- runDB listItems
  pure (recordToDTO cat r)

-- | 여러 기록을 한 번의 카탈로그 로드로 변환한다(기간 조회용).
toRecordDTOs :: [DailyRecord] -> AppM [RecordDTO]
toRecordDTOs rows = do
  cat <- runDB listItems
  pure (map (recordToDTO cat) rows)
