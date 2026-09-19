{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedStrings #-}

-- | 도메인 값 객체의 유일한 생성 경로입니다.
--
-- "Todo.Core.Types"의 생성자는 기술적으로 노출되어 있지만, 정규화되지 않은 값이
-- 도메인에 들어오지 않도록 모든 어댑터는 이 모듈의 스마트 생성자를 사용합니다.
module Todo.Core.Validation (
  ValidationError (..),
  maxTitleLength,
  maxTagLength,
  maxTagCount,
  mkTitle,
  mkTag,
  mkTags,
  mkListId,
  validateDueOn,
  renderValidationError,
) where

import qualified Data.Char as Char
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day)
import Todo.Core.Types (ListId (..), Tag (..), Title (..))

-- | 입력 검증이 거부된 이유입니다. 어댑터는 이 값을 사용자 메시지나 HTTP 오류로 변환합니다.
data ValidationError
  = EmptyTitle
  | TitleTooLong Int
  | EmptyTag
  | TagTooLong Int
  | InvalidTagCharacter Char
  | TooManyTags Int
  | EmptyListId
  | DueDateInPast Day Day
  deriving stock (Eq, Show)

-- | 제목의 최대 문자 수입니다.
maxTitleLength :: Int
maxTitleLength = 200

-- | 태그 하나의 최대 문자 수입니다.
maxTagLength :: Int
maxTagLength = 32

-- | 할 일 하나가 가질 수 있는 최대 태그 수입니다.
maxTagCount :: Int
maxTagCount = 16

-- | 앞뒤 공백을 제거하고 내부 공백을 하나로 접은 제목을 만듭니다.
mkTitle :: Text -> Either ValidationError Title
mkTitle raw
  | T.null normalized = Left EmptyTitle
  | T.length normalized > maxTitleLength = Left (TitleTooLong (T.length normalized))
  | otherwise = Right (Title normalized)
 where
  normalized = T.unwords (T.words raw)

-- | 소문자로 정규화된 태그를 만듭니다. 허용 문자는 문자, 숫자, @-@, @_@입니다.
mkTag :: Text -> Either ValidationError Tag
mkTag raw
  | T.null normalized = Left EmptyTag
  | T.length normalized > maxTagLength = Left (TagTooLong (T.length normalized))
  | otherwise = case T.find (not . isAllowedTagChar) normalized of
      Just bad -> Left (InvalidTagCharacter bad)
      Nothing -> Right (Tag normalized)
 where
  normalized = T.toLower (T.strip raw)

isAllowedTagChar :: Char -> Bool
isAllowedTagChar c = Char.isAlphaNum c || c == '-' || c == '_'

-- | 태그 목록을 정규화합니다. 정규화 후 중복은 하나로 합쳐집니다.
mkTags :: [Text] -> Either ValidationError (Set Tag)
mkTags raws = do
  tags <- traverse mkTag raws
  let unique = Set.fromList tags
  if Set.size unique > maxTagCount
    then Left (TooManyTags (Set.size unique))
    else Right unique

-- | 목록 식별자를 정규화합니다. 태그와 같은 문자 규칙을 사용합니다.
mkListId :: Text -> Either ValidationError ListId
mkListId raw
  | T.null normalized = Left EmptyListId
  | otherwise = case mkTag normalized of
      Left EmptyTag -> Left EmptyListId
      Left err -> Left err
      Right tag -> Right (ListId (unTag tag))
 where
  normalized = T.strip raw

-- | 마감일이 과거가 아닌지 확인합니다. 첫 인자는 경계에서 주입한 오늘 날짜입니다.
validateDueOn :: Day -> Maybe Day -> Either ValidationError (Maybe Day)
validateDueOn _ Nothing = Right Nothing
validateDueOn todayValue (Just due)
  | due < todayValue = Left (DueDateInPast due todayValue)
  | otherwise = Right (Just due)

-- | 사용자에게 보여줄 수 있는 한국어 설명으로 변환합니다.
renderValidationError :: ValidationError -> Text
renderValidationError err = case err of
  EmptyTitle -> "제목이 비어 있습니다."
  TitleTooLong n ->
    "제목이 " <> tshow n <> "자로 최대 " <> tshow maxTitleLength <> "자를 넘었습니다."
  EmptyTag -> "태그가 비어 있습니다."
  TagTooLong n ->
    "태그가 " <> tshow n <> "자로 최대 " <> tshow maxTagLength <> "자를 넘었습니다."
  InvalidTagCharacter c ->
    "태그에 허용되지 않은 문자가 있습니다: " <> T.singleton c
  TooManyTags n ->
    "태그가 " <> tshow n <> "개로 최대 " <> tshow maxTagCount <> "개를 넘었습니다."
  EmptyListId -> "목록 이름이 비어 있습니다."
  DueDateInPast due todayValue ->
    "마감일 " <> tshow due <> "이 오늘 " <> tshow todayValue <> "보다 과거입니다."

tshow :: (Show a) => a -> Text
tshow = T.pack . show
