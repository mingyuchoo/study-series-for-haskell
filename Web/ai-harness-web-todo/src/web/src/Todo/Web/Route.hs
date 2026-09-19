{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedStrings #-}

-- | 요청 경로와 질의 문자열의 해석입니다.
--
-- 순수 모듈입니다. WAI 요청을 직접 다루지 않고 이미 꺼낸 경로 조각과 질의 쌍만
-- 받으므로 라우팅과 질의 해석을 @IO@ 없이 검증할 수 있습니다.
--
-- 이 모듈은 조건을 만들기만 하고 평가하지 않습니다. 평가는 "Todo.Core.Filter"가
-- 합니다. 상태 조건의 기본값과 우선순위도 여기서 정하지 않고
-- 'Todo.Core.Filter.resolveStatusFilter'에 위임합니다. @cli@가 같은 함수를
-- 쓰므로 두 표면의 기본 목록이 같습니다(@docs/product/invariants.md@의 @PROD-INV-003@).
module Todo.Web.Route (
  Route (..),
  ListQuery (..),
  RouteError (..),
  emptyListQuery,
  parseRoute,
  isWriteRoute,
  listFilter,
  renderRouteError,
) where

import qualified Data.Char as Char
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as T
import Text.Read (readMaybe)
import Todo.Core.Filter (
  TodoFilter (..),
  emptyFilter,
  resolveStatusFilter,
 )
import Todo.Core.Types (ListId, Status, Tag, statusFromName)
import Todo.Core.Validation (
  ValidationError,
  mkListId,
  mkTags,
  renderValidationError,
 )

-- | 해석된 요청입니다.
--
-- 조회와 변경을 한 타입에 두고 'isWriteRoute'로 구분합니다. 이렇게 하면 새 변경
-- 경로를 추가할 때 출처 확인을 빠뜨렸는지 한 함수만 보고 알 수 있습니다.
data Route
  = -- | 목록 화면입니다.
    ListRoute ListQuery
  | -- | 할 일 하나의 상세 화면입니다.
    DetailRoute Int
  | -- | 삭제 확인 화면입니다. 삭제 자체는 하지 않습니다.
    DeleteFormRoute Int
  | -- | 새 할 일을 만듭니다.
    CreateRoute
  | -- | 내용을 부분 수정합니다.
    EditRoute Int
  | -- | 상태를 바꿉니다.
    StatusRoute Int
  | -- | 영구 삭제합니다.
    DeleteRoute Int
  | -- | 경로는 있으나 그 메서드를 받지 않습니다.
    MethodMismatch
  | -- | 어느 화면에도 해당하지 않습니다.
    UnknownRoute
  deriving stock (Eq, Show)

-- | 이 요청이 저장소를 바꾸는지 알려줍니다.
--
-- 'Todo.Web.Server'가 이 값으로 출처 확인 여부를 정합니다. 새 경로를 추가하면서
-- 여기에 넣지 않으면 확인 없이 통과하므로, 변경 경로를 늘릴 때는 이 함수와
-- @../tests/Todo/Web/SecuritySpec.hs@를 함께 봅니다.
isWriteRoute :: Route -> Bool
isWriteRoute route = case route of
  CreateRoute -> True
  EditRoute _ -> True
  StatusRoute _ -> True
  DeleteRoute _ -> True
  ListRoute _ -> False
  DetailRoute _ -> False
  DeleteFormRoute _ -> False
  MethodMismatch -> False
  UnknownRoute -> False

-- | 목록 화면이 받는 조건입니다.
--
-- 사용자가 무엇을 요청했는지 그대로 담습니다. 화면이 현재 조건을 표시하려면
-- 'TodoFilter'만으로는 부족하기 때문입니다.
data ListQuery = ListQuery
  { queryStatus :: Maybe Status
  , queryShowAll :: Bool
  , queryTags :: Set Tag
  , queryListId :: Maybe ListId
  }
  deriving stock (Eq, Show)

-- | 아무 조건도 지정하지 않은 목록 요청입니다.
emptyListQuery :: ListQuery
emptyListQuery =
  ListQuery
    { queryStatus = Nothing
    , queryShowAll = False
    , queryTags = Set.empty
    , queryListId = Nothing
    }

-- | 질의 문자열을 해석하지 못한 이유입니다.
data RouteError
  = -- | 알 수 없는 상태 이름입니다.
    UnknownStatusName Text
  | -- | 값 검증이 거부했습니다.
    InvalidQueryValue ValidationError
  deriving stock (Eq, Show)

-- | 메서드와 경로 조각, 질의 쌍을 하나의 요청으로 해석합니다.
--
-- 질의 값이 없는 쌍(@?all@)은 값이 빈 문자열인 것과 같게 다룹니다. 사람이 주소창에
-- 직접 입력하는 표면이므로 두 형태를 구분하지 않습니다.
--
-- 변경은 모두 @POST@입니다. @PUT@과 @DELETE@를 쓰지 않는 이유는 HTML 폼이 두
-- 메서드를 보낼 수 없기 때문입니다. 메서드를 숨은 필드로 위장하는 방법은 쓰지
-- 않습니다. 경로에 동작을 적는 편이 읽기 쉽고, 이 표면의 주소는 계약이 아닙니다.
parseRoute :: Text -> [Text] -> [(Text, Maybe Text)] -> Either RouteError Route
parseRoute method path params = case path of
  [] -> onGet (ListRoute <$> parseListQuery params)
  ["todos"]
    | isGet -> ListRoute <$> parseListQuery params
    | isPost -> pure CreateRoute
    | otherwise -> pure MethodMismatch
  ["todos", rawId] -> withTodoId rawId (\todoId -> onGet (pure (DetailRoute todoId)))
  ["todos", rawId, "edit"] -> withTodoId rawId (\todoId -> onPost (pure (EditRoute todoId)))
  ["todos", rawId, "status"] -> withTodoId rawId (\todoId -> onPost (pure (StatusRoute todoId)))
  ["todos", rawId, "delete"] ->
    withTodoId rawId $ \todoId ->
      if isGet
        then pure (DeleteFormRoute todoId)
        else
          if isPost
            then pure (DeleteRoute todoId)
            else pure MethodMismatch
  _ -> pure UnknownRoute
 where
  isGet = method == "GET"
  isPost = method == "POST"

  onGet action = if isGet then action else pure MethodMismatch
  onPost action = if isPost then action else pure MethodMismatch

  -- 식별자를 읽지 못하면 메서드와 무관하게 없는 화면입니다.
  withTodoId raw continue = maybe (pure UnknownRoute) continue (readTodoId raw)

-- | 목록 조건을 해석합니다.
parseListQuery :: [(Text, Maybe Text)] -> Either RouteError ListQuery
parseListQuery params = do
  status <- traverse parseStatus (lookupNonEmpty "status" params)
  tags <- first InvalidQueryValue (mkTags (lookupAll "tag" params))
  listId <- first InvalidQueryValue (traverse mkListId (lookupNonEmpty "list" params))
  pure
    ListQuery
      { queryStatus = status
      , queryShowAll = isFlagSet "all" params
      , queryTags = tags
      , queryListId = listId
      }

-- | 해석한 조건을 도메인 조회 조건으로 옮깁니다.
--
-- 조건의 의미를 여기서 다시 정하지 않습니다. 상태 기본값은
-- 'Todo.Core.Filter.resolveStatusFilter'가 답합니다.
listFilter :: ListQuery -> TodoFilter
listFilter query =
  emptyFilter
    { filterStatus = resolveStatusFilter (queryStatus query) (queryShowAll query)
    , filterTags = queryTags query
    , filterListId = queryListId query
    }

-- | 해석 실패를 사용자 문구로 바꿉니다.
--
-- 내부 구조나 입력값 전체를 노출하지 않습니다.
renderRouteError :: RouteError -> Text
renderRouteError err = case err of
  UnknownStatusName name -> "알 수 없는 상태입니다: " <> name
  InvalidQueryValue validationError -> renderValidationError validationError

-- 보조 함수 ------------------------------------------------------------------

parseStatus :: Text -> Either RouteError Status
parseStatus raw = maybe (Left (UnknownStatusName raw)) Right (statusFromName raw)

-- | 값이 있고 비어 있지 않은 첫 항목입니다. 빈 값은 지정하지 않은 것으로 봅니다.
lookupNonEmpty :: Text -> [(Text, Maybe Text)] -> Maybe Text
lookupNonEmpty key params =
  case [value | (k, Just value) <- params, k == key, not (T.null value)] of
    (value : _) -> Just value
    [] -> Nothing

-- | 같은 이름으로 여러 번 온 값을 모두 모읍니다. 태그는 여러 개를 지정할 수 있습니다.
lookupAll :: Text -> [(Text, Maybe Text)] -> [Text]
lookupAll key params =
  [value | (k, Just value) <- params, k == key, not (T.null value)]

-- | 값 없는 쌍이나 @0@, @false@가 아닌 값이 오면 켜진 것으로 봅니다.
isFlagSet :: Text -> [(Text, Maybe Text)] -> Bool
isFlagSet key params =
  case [value | (k, value) <- params, k == key] of
    [] -> False
    (Nothing : _) -> True
    (Just value : _) -> value `notElem` ["0", "false"]

-- | 식별자는 부호 없는 십진수만 받습니다.
--
-- 부호와 공백을 허용하지 않는 것은 @/todos/-1@ 이나 @/todos/ 1@ 같은 경로가
-- 조회로 이어지지 않게 하기 위함입니다.
readTodoId :: Text -> Maybe Int
readTodoId raw
  | T.null raw = Nothing
  | not (T.all Char.isDigit raw) = Nothing
  | otherwise = readMaybe (T.unpack raw)

first :: (a -> c) -> Either a b -> Either c b
first f = either (Left . f) Right
