{-# LANGUAGE RecordWildCards #-}

-- | 일별 기록 핸들러 (기간 조회, 단일 조회, 저장).
module Luck.Handler.Record
  ( recordsH
  , recordH
  , putRecordH
  ) where

import Control.Monad.Except (throwError)
import Control.Monad.IO.Class (liftIO)
import Control.Monad.Reader (ask)
import Data.Maybe (fromMaybe)
import Data.Time (Day)
import Luck.App (AppEnv (..), AppM)
import Luck.Domain.Checklist (sanitize)
import Luck.Domain.Record (DailyRecord (..))
import Luck.Error (DomainError (..))
import Luck.Repository.Record (getRecord, getRecordsBetween, upsertRecord)
import Luck.Types
import Luck.Web.Dto (recordToDTO)
import Luck.Web.Error (toServerError)

recordsH :: AuthUser -> Maybe Day -> Maybe Day -> AppM [RecordDTO]
recordsH u mFrom mTo =
  case (mFrom, mTo) of
    (Just from, Just to) -> do
      env <- ask
      rows <- liftIO (getRecordsBetween (envPool env) (auId u) from to)
      pure (map recordToDTO rows)
    _ -> throwError (toServerError (ValidationError "from, to 쿼리 파라미터가 필요합니다."))

recordH :: AuthUser -> Day -> AppM RecordDTO
recordH u d = do
  env <- ask
  mrow <- liftIO (getRecord (envPool env) (auId u) d)
  pure (recordToDTO (fromMaybe (DailyRecord d [] Nothing) mrow))

putRecordH :: AuthUser -> Day -> RecordUpdate -> AppM RecordDTO
putRecordH u d RecordUpdate{..} = do
  env <- ask
  saved <- liftIO (upsertRecord (envPool env) (auId u) d (sanitize ruCompleted) ruNote)
  pure (recordToDTO saved)
