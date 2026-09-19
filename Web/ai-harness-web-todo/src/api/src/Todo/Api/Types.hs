{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedStrings #-}

-- | HTTP 전송 표현입니다.
--
-- 도메인 타입을 그대로 직렬화하지 않습니다. 도메인 구조를 바꿀 때마다 공개 계약이
-- 함께 깨지는 것을 막기 위한 결정이며 @docs/decisions/ADR-0003-api-boundary.md@에 있습니다.
--
-- 필드 이름과 의미의 Canonical Source는 @docs/contracts/api/TODO-API-v1.md@입니다.
-- 인스턴스를 자동 파생하지 않고 손으로 적는 이유는, 필드 이름 변경이 계약 변경임을
-- 코드에서 눈에 보이게 하기 위해서입니다.
module Todo.Api.Types (
  TodoDto (..),
  NewTodoDto (..),
  PatchTodoDto (..),
  StatusDto (..),
  ApiError (..),
  toTodoDto,
) where

import Data.Aeson (
  FromJSON (..),
  ToJSON (..),
  object,
  withObject,
  (.:),
  (.:!),
  (.:?),
  (.=),
 )
import qualified Data.Set as Set
import Data.Text (Text)
import Data.Time (Day, UTCTime)
import Todo.Core.Types (
  ListId (..),
  Tag (..),
  Title (..),
  Todo (..),
  TodoId (..),
  priorityName,
  statusName,
 )

-- | 응답으로 나가는 할 일 표현입니다.
data TodoDto = TodoDto
  { dtoId :: Int
  , dtoTitle :: Text
  , dtoList :: Text
  , dtoStatus :: Text
  , dtoPriority :: Text
  , dtoTags :: [Text]
  , dtoDueOn :: Maybe Day
  , dtoCreatedAt :: UTCTime
  , dtoUpdatedAt :: UTCTime
  }
  deriving stock (Eq, Show)

instance ToJSON TodoDto where
  toJSON dto =
    object
      [ "id" .= dtoId dto
      , "title" .= dtoTitle dto
      , "list" .= dtoList dto
      , "status" .= dtoStatus dto
      , "priority" .= dtoPriority dto
      , "tags" .= dtoTags dto
      , "dueOn" .= dtoDueOn dto
      , "createdAt" .= dtoCreatedAt dto
      , "updatedAt" .= dtoUpdatedAt dto
      ]

instance FromJSON TodoDto where
  parseJSON = withObject "TodoDto" $ \o ->
    TodoDto
      <$> o .: "id"
      <*> o .: "title"
      <*> o .: "list"
      <*> o .: "status"
      <*> o .: "priority"
      <*> o .: "tags"
      <*> o .:? "dueOn"
      <*> o .: "createdAt"
      <*> o .: "updatedAt"

-- | 생성 요청 본문입니다. @title@만 필수입니다.
data NewTodoDto = NewTodoDto
  { newDtoTitle :: Text
  , newDtoList :: Maybe Text
  , newDtoPriority :: Maybe Text
  , newDtoTags :: Maybe [Text]
  , newDtoDueOn :: Maybe Day
  }
  deriving stock (Eq, Show)

instance FromJSON NewTodoDto where
  parseJSON = withObject "NewTodoDto" $ \o ->
    NewTodoDto
      <$> o .: "title"
      <*> o .:? "list"
      <*> o .:? "priority"
      <*> o .:? "tags"
      <*> o .:? "dueOn"

instance ToJSON NewTodoDto where
  toJSON dto =
    object
      [ "title" .= newDtoTitle dto
      , "list" .= newDtoList dto
      , "priority" .= newDtoPriority dto
      , "tags" .= newDtoTags dto
      , "dueOn" .= newDtoDueOn dto
      ]

-- | 부분 수정 요청 본문입니다.
--
-- @dueOn@은 세 가지 경우를 구분합니다.
--
-- * 필드 없음: 마감일을 바꾸지 않습니다.
-- * @null@: 마감일을 제거합니다.
-- * 날짜: 마감일을 그 값으로 바꿉니다.
data PatchTodoDto = PatchTodoDto
  { patchDtoTitle :: Maybe Text
  , patchDtoList :: Maybe Text
  , patchDtoPriority :: Maybe Text
  , patchDtoTags :: Maybe [Text]
  , patchDtoDueOn :: Maybe (Maybe Day)
  }
  deriving stock (Eq, Show)

instance FromJSON PatchTodoDto where
  parseJSON = withObject "PatchTodoDto" $ \o ->
    PatchTodoDto
      <$> o .:? "title"
      <*> o .:? "list"
      <*> o .:? "priority"
      <*> o .:? "tags"
      <*> o .:! "dueOn"

instance ToJSON PatchTodoDto where
  toJSON dto =
    object
      [ "title" .= patchDtoTitle dto
      , "list" .= patchDtoList dto
      , "priority" .= patchDtoPriority dto
      , "tags" .= patchDtoTags dto
      , "dueOn" .= patchDtoDueOn dto
      ]

-- | 상태 변경 요청 본문입니다.
newtype StatusDto = StatusDto {statusDtoStatus :: Text}
  deriving stock (Eq, Show)

instance FromJSON StatusDto where
  parseJSON = withObject "StatusDto" $ \o -> StatusDto <$> o .: "status"

instance ToJSON StatusDto where
  toJSON dto = object ["status" .= statusDtoStatus dto]

-- | 모든 오류 응답의 공통 본문입니다.
--
-- 소비자는 HTTP 상태 코드가 아니라 @code@로 분기합니다. 상태 코드는 전송 계층의
-- 신호이고 @code@가 안정적인 계약입니다.
data ApiError = ApiError
  { apiErrorCode :: Text
  , apiErrorMessage :: Text
  }
  deriving stock (Eq, Show)

instance ToJSON ApiError where
  toJSON err =
    object
      [ "code" .= apiErrorCode err
      , "message" .= apiErrorMessage err
      ]

instance FromJSON ApiError where
  parseJSON = withObject "ApiError" $ \o ->
    ApiError <$> o .: "code" <*> o .: "message"

-- | 도메인 값을 전송 표현으로 옮깁니다. 반대 방향은 "Todo.Api.Server"가 담당합니다.
toTodoDto :: Todo -> TodoDto
toTodoDto todo =
  TodoDto
    { dtoId = unTodoId (todoId todo)
    , dtoTitle = unTitle (todoTitle todo)
    , dtoList = unListId (todoListId todo)
    , dtoStatus = statusName (todoStatus todo)
    , dtoPriority = priorityName (todoPriority todo)
    , dtoTags = map unTag (Set.toAscList (todoTags todo))
    , dtoDueOn = todoDueOn todo
    , dtoCreatedAt = todoCreatedAt todo
    , dtoUpdatedAt = todoUpdatedAt todo
    }
