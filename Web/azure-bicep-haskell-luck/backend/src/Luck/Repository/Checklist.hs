-- | checklist_items 테이블 접근. 도메인 'ChecklistItem' 으로 결과를 돌려준다.
--   외부 DTO/HTTP는 모른다 (변환은 'Luck.Web.Dto').
module Luck.Repository.Checklist
    ( deleteItem
    , insertItem
    , listAllItems
    , listItems
    , setActive
    , updateItem
    ) where

import           Control.Exception          (try)
import           Data.Pool                  (Pool)
import           Data.Text                  (Text)
import           Database.PostgreSQL.Simple
import           Luck.DB                    (withConn)
import           Luck.Domain.Checklist      (ChecklistItem (..))
import           Luck.Error                 (DomainError (..))

-- | "오늘" 화면/달성률에 쓰이는 활성 항목만 정렬 순서대로 조회한다.
listItems :: Pool Connection -> IO [ChecklistItem]
listItems pool = withConn pool $ \c -> do
  rows <-
    query_
      c
      "SELECT key, label, active FROM checklist_items WHERE active ORDER BY sort_order, key"
  pure (map toItem rows)

-- | 관리 화면용: 비활성 항목까지 포함한 모든 항목을 정렬 순서대로 조회한다.
listAllItems :: Pool Connection -> IO [ChecklistItem]
listAllItems pool = withConn pool $ \c -> do
  rows <-
    query_
      c
      "SELECT key, label, active FROM checklist_items ORDER BY sort_order, key"
  pure (map toItem rows)

-- | 새 항목을 추가한다. key는 서버가 @d{n}@ 형태로 자동 생성한다
--   (기존 @d숫자@ key 중 최대 번호 + 1). 정렬 순서는 맨 뒤, 활성 상태로 생성.
--   동시 추가로 key가 충돌(23505)하면 @Left Conflict@.
insertItem :: Pool Connection -> Text -> IO (Either DomainError ChecklistItem)
insertItem pool label = withConn pool $ \c -> do
  res <-
    try $
      query
        c
        "INSERT INTO checklist_items (key, label, sort_order, active)\
        \ SELECT\
        \   'd' || (COALESCE(MAX((substring(key from '^d([0-9]+)$'))::int), 0) + 1),\
        \   ?,\
        \   COALESCE(MAX(sort_order), 0) + 1,\
        \   true\
        \ FROM checklist_items\
        \ RETURNING key, label, active"
        (Only label)
  case res of
    Left e
      | sqlState e == "23505" -> pure (Left (Conflict "key 생성 충돌이 발생했습니다. 다시 시도하세요."))
      | otherwise -> pure (Left (InternalError "항목 추가 중 오류가 발생했습니다."))
    Right (row : _) -> pure (Right (toItem row))
    Right [] -> pure (Left (InternalError "항목 추가에 실패했습니다."))

-- | 항목의 라벨을 갱신한다. 해당 key가 없으면 @Nothing@.
updateItem :: Pool Connection -> Text -> Text -> IO (Maybe ChecklistItem)
updateItem pool key label = withConn pool $ \c -> do
  rows <-
    query
      c
      "UPDATE checklist_items SET label = ? WHERE key = ? RETURNING key, label, active"
      (label, key)
  pure (toMaybe rows)

-- | 항목의 활성 상태를 갱신한다. 해당 key가 없으면 @Nothing@.
setActive :: Pool Connection -> Text -> Bool -> IO (Maybe ChecklistItem)
setActive pool key active = withConn pool $ \c -> do
  rows <-
    query
      c
      "UPDATE checklist_items SET active = ? WHERE key = ? RETURNING key, label, active"
      (active, key)
  pure (toMaybe rows)

-- | 항목을 삭제한다. 삭제된 행이 있으면 @True@, 없으면 @False@.
deleteItem :: Pool Connection -> Text -> IO Bool
deleteItem pool key = withConn pool $ \c -> do
  n <- execute c "DELETE FROM checklist_items WHERE key = ?" (Only key)
  pure (n > 0)

-- | DB 행(튜플)을 도메인 'ChecklistItem' 으로 변환.
toItem :: (Text, Text, Bool) -> ChecklistItem
toItem (k, l, a) = ChecklistItem k l a

-- | RETURNING 결과의 첫 행을 'ChecklistItem' 으로.
toMaybe :: [(Text, Text, Bool)] -> Maybe ChecklistItem
toMaybe (row : _) = Just (toItem row)
toMaybe []        = Nothing
