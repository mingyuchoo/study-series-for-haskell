-- | 체크리스트 도메인: 항목 엔티티('ChecklistItem')와 그에 의존하는 순수 규칙
--   (전체 항목 수, 알 수 없는 key 정리, 입력 검증). 웹/DB를 모른다.
--
--   항목 정본은 DB(@checklist_items@)에 있고, 웹 경계 DTO 변환은 'Luck.Web.Dto'가
--   담당한다. 이 모듈은 항목을 값으로 받아 동작할 뿐 표현 방식을 모른다.
module Luck.Domain.Checklist
    ( ChecklistItem (..)
    , catalogKeys
    , sanitize
    , total
    , validateChecklistLabel
    ) where

import           Data.Char  (isSpace)
import qualified Data.Set   as Set
import           Data.Text  (Text)
import qualified Data.Text  as T
import           Luck.Error (DomainError (..))

-- | 체크리스트 항목 (도메인 엔티티). @chActive@ 가 false면 "오늘" 화면에서 숨겨진다.
data ChecklistItem = ChecklistItem
  { chKey    :: Text
  , chLabel  :: Text
  , chActive :: Bool
  }
  deriving stock (Show, Eq)

-- | 유효한 항목 key 집합 (저장 시 알 수 없는 key를 걸러내기 위함).
catalogKeys :: [ChecklistItem] -> Set.Set Text
catalogKeys = Set.fromList . map chKey

-- | 전체 일별 항목 수 (달성률 계산용).
total :: [ChecklistItem] -> Int
total = length

-- | 알 수 없는 key 제거 + 중복 제거 (현재 카탈로그 기준).
sanitize :: [ChecklistItem] -> [Text] -> [Text]
sanitize cat xs =
  Set.toList (Set.intersection (catalogKeys cat) (Set.fromList xs))

-- | 항목 라벨 검증 (1~200자). 검증은 도메인 규칙이므로 항목 도메인에 둔다.
validateChecklistLabel :: Text -> Either DomainError ()
validateChecklistLabel label
  | T.null l = Left (ValidationError "항목 내용을 입력하세요.")
  | T.length l > 200 = Left (ValidationError "항목 내용은 200자 이하여야 합니다.")
  | otherwise = Right ()
  where
    l = T.dropWhileEnd isSpace (T.dropWhile isSpace label)
