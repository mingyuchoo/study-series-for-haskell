{-# LANGUAGE RecordWildCards #-}

-- | 관리자 전용 핸들러: 체크리스트 항목(catalog) CRUD.
--   모든 핸들러는 'requireAdmin' 으로 관리자 권한을 먼저 확인한다 (아니면 403).
module Luck.Handler.Admin
    ( createItemH
    , deleteItemH
    , listItemsH
    , setActiveH
    , updateItemH
    ) where

import           Control.Monad.Except      (throwError)
import           Control.Monad.IO.Class    (liftIO)
import           Control.Monad.Reader      (ask)
import           Data.Text                 (Text)
import qualified Data.Text                 as T
import           Luck.App                  (AppEnv (..), AppM)
import           Luck.Domain.Validation    (validateChecklistLabel)
import           Luck.Error                (DomainError (..))
import           Luck.Repository.Checklist
    ( deleteItem
    , insertItem
    , listAllItems
    , setActive
    , updateItem
    )
import           Luck.Repository.User      (UserRow (..), getUserById)
import           Luck.Types
import           Luck.Web.Error            (toServerError)

-- | 현재 인증 사용자가 관리자인지 DB에서 확인한다. 관리자가 아니면 403.
--   (JWT에 굽지 않고 매 요청마다 DB를 확인하므로 권한 회수가 즉시 반영된다.)
requireAdmin :: AuthUser -> AppM ()
requireAdmin u = do
  env <- ask
  mrow <- liftIO (getUserById (envPool env) (auId u))
  case mrow of
    Just row | urIsAdmin row -> pure ()
    _ -> throwError (toServerError (Forbidden "관리자 권한이 필요합니다."))

-- | 관리 화면용 항목 목록 (비활성 항목 포함). 공개 /catalog 는 활성 항목만 준다.
listItemsH :: AuthUser -> AppM [CatalogItem]
listItemsH u = do
  requireAdmin u
  env <- ask
  liftIO (listAllItems (envPool env))

-- | 항목 생성. label만 검증하고 key는 서버가 자동 생성한다.
createItemH :: AuthUser -> ChecklistCreateReq -> AppM CatalogItem
createItemH u ChecklistCreateReq {..} = do
  requireAdmin u
  let label = T.strip ccLabel
  orThrow (validateChecklistLabel label)
  env <- ask
  res <- liftIO (insertItem (envPool env) label)
  either (throwError . toServerError) pure res

-- | 항목 활성/비활성 토글. key는 URL에서, 상태는 본문에서 받는다. 없으면 404.
setActiveH :: AuthUser -> Text -> ChecklistActiveReq -> AppM CatalogItem
setActiveH u key ChecklistActiveReq {..} = do
  requireAdmin u
  env <- ask
  mItem <- liftIO (setActive (envPool env) key caActive)
  maybe (throwError (toServerError (NotFound "항목을 찾을 수 없습니다."))) pure mItem

-- | 항목 수정. key는 URL에서, 라벨은 본문에서 받는다. 없으면 404.
updateItemH :: AuthUser -> Text -> ChecklistUpdateReq -> AppM CatalogItem
updateItemH u key ChecklistUpdateReq {..} = do
  requireAdmin u
  let label = T.strip cuLabel
  orThrow (validateChecklistLabel label)
  env <- ask
  mItem <- liftIO (updateItem (envPool env) key label)
  maybe (throwError (toServerError (NotFound "항목을 찾을 수 없습니다."))) pure mItem

-- | 항목 삭제. 없으면 404.
deleteItemH :: AuthUser -> Text -> AppM MessageResp
deleteItemH u key = do
  requireAdmin u
  env <- ask
  ok <- liftIO (deleteItem (envPool env) key)
  if ok
    then pure (MessageResp "삭제되었습니다.")
    else throwError (toServerError (NotFound "항목을 찾을 수 없습니다."))

-- | 검증 결과가 실패면 HTTP 에러로 던진다.
orThrow :: Either DomainError () -> AppM ()
orThrow = either (throwError . toServerError) pure
