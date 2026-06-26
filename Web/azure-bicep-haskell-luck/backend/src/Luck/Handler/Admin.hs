{-# LANGUAGE RecordWildCards #-}

-- | 관리자 전용 핸들러: 체크리스트 항목 CRUD.
--   권한 검사는 'Luck.Authz.requireAdmin' 으로 위임한다 (아니면 403).
module Luck.Handler.Admin
    ( createItemH
    , deleteItemH
    , listItemsH
    , setActiveH
    , updateItemH
    ) where

import           Control.Monad.Except      (throwError)
import           Data.Text                 (Text)
import qualified Data.Text                 as T
import           Luck.App                  (AppM)
import           Luck.Authz                (requireAdmin)
import           Luck.Domain.Checklist     (validateChecklistLabel)
import           Luck.Error                (DomainError (..))
import           Luck.Handler.Util         (liftEither, note404, runDB)
import           Luck.Repository.Checklist
    ( deleteItem
    , insertItem
    , listAllItems
    , setActive
    , updateItem
    )
import           Luck.Types.Auth           (AuthUser)
import           Luck.Types.Checklist
    ( AdminCatalogItem
    , ChecklistActiveReq (..)
    , ChecklistCreateReq (..)
    , ChecklistUpdateReq (..)
    )
import           Luck.Types.Common         (MessageResp (..))
import           Luck.Web.Dto              (checklistItemToAdmin)
import           Luck.Web.Error            (toServerError)

-- | 관리 화면용 항목 목록 (비활성 포함). 공개 /catalog 는 활성만 준다.
listItemsH :: AuthUser -> AppM [AdminCatalogItem]
listItemsH u = do
  requireAdmin u
  map checklistItemToAdmin <$> runDB listAllItems

-- | 항목 생성. label만 검증하고 key는 서버가 자동 생성한다.
createItemH :: AuthUser -> ChecklistCreateReq -> AppM AdminCatalogItem
createItemH u ChecklistCreateReq {..} = do
  requireAdmin u
  let label = T.strip ccLabel
  liftEither (validateChecklistLabel label)
  item <- liftEither =<< runDB (\p -> insertItem p label)
  pure (checklistItemToAdmin item)

-- | 항목 라벨 수정. key는 URL에서, 라벨은 본문에서. 없으면 404.
updateItemH :: AuthUser -> Text -> ChecklistUpdateReq -> AppM AdminCatalogItem
updateItemH u key ChecklistUpdateReq {..} = do
  requireAdmin u
  let label = T.strip cuLabel
  liftEither (validateChecklistLabel label)
  mItem <- runDB (\p -> updateItem p key label)
  checklistItemToAdmin <$> note404 "항목을 찾을 수 없습니다." mItem

-- | 항목 활성/비활성 토글. key는 URL에서, 상태는 본문에서. 없으면 404.
setActiveH :: AuthUser -> Text -> ChecklistActiveReq -> AppM AdminCatalogItem
setActiveH u key ChecklistActiveReq {..} = do
  requireAdmin u
  mItem <- runDB (\p -> setActive p key caActive)
  checklistItemToAdmin <$> note404 "항목을 찾을 수 없습니다." mItem

-- | 항목 삭제. 없으면 404.
deleteItemH :: AuthUser -> Text -> AppM MessageResp
deleteItemH u key = do
  requireAdmin u
  ok <- runDB (\p -> deleteItem p key)
  if ok
    then pure (MessageResp "삭제되었습니다.")
    else throwError (toServerError (NotFound "항목을 찾을 수 없습니다."))
