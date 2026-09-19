{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedStrings #-}

-- | 폼 본문의 해석입니다.
--
-- 순수 모듈입니다. 이미 해석한 필드 쌍만 받으므로 @IO@ 없이 검증할 수 있습니다.
--
-- 값 검증을 여기서 다시 구현하지 않습니다. 제목, 태그, 목록 이름, 마감일은 모두
-- "Todo.Core.Validation"이 판단하고 이 모듈은 폼 필드를 그 함수들에 넘기기만 합니다.
module Todo.Web.Form (
  FormError (..),
  parseNewTodo,
  parsePatch,
  parseStatusChange,
  renderFormError,
) where

import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, UTCTime)
import Data.Time.Format (defaultTimeLocale, parseTimeM)
import Todo.Core.Repository (NewTodo (..), TodoPatch (..), emptyPatch)
import Todo.Core.Types (
  Priority (..),
  Status,
  Tag,
  Title,
  defaultListId,
  priorityFromName,
  statusFromName,
 )
import Todo.Core.Validation (
  ValidationError,
  mkListId,
  mkTags,
  mkTitle,
  renderValidationError,
  validateDueOn,
 )

-- | 폼을 해석하지 못한 이유입니다.
data FormError
  = -- | 필수 필드가 없습니다.
    MissingField Text
  | -- | 알 수 없는 상태 이름입니다.
    UnknownStatusValue Text
  | -- | 알 수 없는 우선순위 이름입니다.
    UnknownPriorityValue Text
  | -- | 날짜 형식이 아닙니다.
    MalformedDate Text
  | -- | 값 검증이 거부했습니다.
    RejectedValue ValidationError
  deriving stock (Eq, Show)

-- | 새 할 일 폼을 해석합니다.
--
-- 목록을 비워 두면 기본 목록에 들어갑니다. 우선순위를 비워 두면 보통입니다.
-- 두 기본값은 @api@의 @POST \/todos@와 같습니다.
parseNewTodo :: UTCTime -> Day -> [(Text, Text)] -> Either FormError NewTodo
parseNewTodo now today fields = do
  rawTitle <- required "title" fields
  title <- parseTitle rawTitle
  listId <- case optional "list" fields of
    Nothing -> pure defaultListId
    Just raw -> first RejectedValue (mkListId raw)
  priority <- maybe (pure Normal) parsePriority (optional "priority" fields)
  tags <- parseTags fields
  dueOn <- parseDueOn (optional "due" fields)
  validated <- first RejectedValue (validateDueOn today dueOn)
  pure
    NewTodo
      { newTitle = title
      , newListId = listId
      , newPriority = priority
      , newTags = tags
      , newDueOn = validated
      , newCreatedAt = now
      }

-- | 수정 폼을 해석합니다.
--
-- 마감일의 세 경우는 계약과 같게 다룹니다. 필드가 없으면 바꾸지 않고, 비어 있으면
-- 지우고, 값이 있으면 그 값으로 바꿉니다. HTML 폼은 빈 입력도 필드를 보내므로
-- 화면에서 날짜를 비우는 것이 곧 제거 요청입니다.
--
-- 수정에서는 마감일이 과거인지 검사하지 않습니다. 이미 지난 마감일을 가진 할 일의
-- 제목만 고치는 것을 막지 않기 위해서이며, @api@의 @PATCH@와 같습니다.
parsePatch :: [(Text, Text)] -> Either FormError TodoPatch
parsePatch fields = do
  title <- traverse parseTitle (optional "title" fields)
  listId <- traverse (first RejectedValue . mkListId) (optional "list" fields)
  priority <- traverse parsePriority (optional "priority" fields)
  tags <- if hasField "tags" fields then Just <$> parseTags fields else pure Nothing
  dueOn <-
    if hasField "due" fields
      then Just <$> parseDueOn (optional "due" fields)
      else pure Nothing
  pure
    emptyPatch
      { patchTitle = title
      , patchListId = listId
      , patchPriority = priority
      , patchTags = tags
      , patchDueOn = dueOn
      }

-- | 상태 변경 폼을 해석합니다.
parseStatusChange :: [(Text, Text)] -> Either FormError Status
parseStatusChange fields = do
  raw <- required "status" fields
  maybe (Left (UnknownStatusValue raw)) Right (statusFromName raw)

-- | 해석 실패를 사용자 문구로 바꿉니다.
renderFormError :: FormError -> Text
renderFormError err = case err of
  MissingField name -> "값이 필요합니다: " <> name
  UnknownStatusValue raw -> "알 수 없는 상태입니다: " <> raw
  UnknownPriorityValue raw -> "알 수 없는 우선순위입니다: " <> raw
  MalformedDate raw -> "날짜 형식이 아닙니다: " <> raw
  RejectedValue validationError -> renderValidationError validationError

-- 필드 접근 ------------------------------------------------------------------

-- | 값이 있고 비어 있지 않은 첫 항목입니다.
optional :: Text -> [(Text, Text)] -> Maybe Text
optional key fields =
  case [value | (k, value) <- fields, k == key, not (T.null value)] of
    (value : _) -> Just value
    [] -> Nothing

-- | 비어 있더라도 필드가 왔는지 봅니다. 값을 지우는 요청과 구분하기 위해서입니다.
hasField :: Text -> [(Text, Text)] -> Bool
hasField key fields = any ((== key) . fst) fields

required :: Text -> [(Text, Text)] -> Either FormError Text
required key fields = maybe (Left (MissingField key)) Right (optional key fields)

-- 값 변환 --------------------------------------------------------------------

parseTitle :: Text -> Either FormError Title
parseTitle = first RejectedValue . mkTitle

parsePriority :: Text -> Either FormError Priority
parsePriority raw = maybe (Left (UnknownPriorityValue raw)) Right (priorityFromName raw)

-- | 태그는 공백으로 나눈 한 줄로 받습니다. 정규화와 개수 제한은 도메인이 합니다.
parseTags :: [(Text, Text)] -> Either FormError (Set Tag)
parseTags fields = case optional "tags" fields of
  Nothing -> pure Set.empty
  Just raw -> first RejectedValue (mkTags (T.words raw))

parseDueOn :: Maybe Text -> Either FormError (Maybe Day)
parseDueOn Nothing = pure Nothing
parseDueOn (Just raw) =
  maybe (Left (MalformedDate raw)) (pure . Just) (parseDay raw)

parseDay :: Text -> Maybe Day
parseDay raw = parseTimeM True defaultTimeLocale "%Y-%m-%d" (T.unpack raw)

first :: (a -> c) -> Either a b -> Either c b
first f = either (Left . f) Right
