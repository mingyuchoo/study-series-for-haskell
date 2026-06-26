-- | daily_records 테이블 접근. 도메인 'DailyRecord' 로 결과를 돌려준다.
module Luck.Repository.Record
  ( getRecord
  , getRecordsBetween
  , upsertRecord
  ) where

import Data.Pool (Pool)
import Data.Text (Text)
import Data.Time (Day)
import Data.UUID (UUID)
import Database.PostgreSQL.Simple
import Database.PostgreSQL.Simple.Newtypes (Aeson (..))
import Luck.DB (withConn)
import Luck.Domain.Record (DailyRecord (..))

-- | 특정 날짜의 기록을 조회한다.
getRecord :: Pool Connection -> UUID -> Day -> IO (Maybe DailyRecord)
getRecord pool uid d = withConn pool $ \c -> do
  rows <-
    query
      c
      "SELECT record_date, completed, note FROM daily_records\
      \ WHERE user_id = ? AND record_date = ?"
      (uid, d)
  pure (fmap toRecord (listToMaybe' rows))

-- | 기간 내 기록 목록을 조회한다 (달력용).
getRecordsBetween :: Pool Connection -> UUID -> Day -> Day -> IO [DailyRecord]
getRecordsBetween pool uid from to = withConn pool $ \c -> do
  rows <-
    query
      c
      "SELECT record_date, completed, note FROM daily_records\
      \ WHERE user_id = ? AND record_date BETWEEN ? AND ?\
      \ ORDER BY record_date"
      (uid, from, to)
  pure (map toRecord rows)

-- | 하루치 기록을 upsert 하고 저장된 결과를 돌려준다.
upsertRecord
  :: Pool Connection -> UUID -> Day -> [Text] -> Maybe Text -> IO DailyRecord
upsertRecord pool uid d completed note = withConn pool $ \c -> do
  rows <-
    query
      c
      "INSERT INTO daily_records (user_id, record_date, completed, note, updated_at)\
      \ VALUES (?, ?, ?, ?, now())\
      \ ON CONFLICT (user_id, record_date)\
      \ DO UPDATE SET completed = EXCLUDED.completed, note = EXCLUDED.note, updated_at = now()\
      \ RETURNING record_date, completed, note"
      (uid, d, Aeson completed, note)
  pure $ case rows of
    (row : _) -> toRecord row
    [] -> DailyRecord d completed note

-- | DB 행(튜플)을 도메인 'DailyRecord' 로 변환.
toRecord :: (Day, Aeson [Text], Maybe Text) -> DailyRecord
toRecord (rd, Aeson cs, note) = DailyRecord rd cs note

-- | 안전한 head.
listToMaybe' :: [a] -> Maybe a
listToMaybe' [] = Nothing
listToMaybe' (x : _) = Just x
