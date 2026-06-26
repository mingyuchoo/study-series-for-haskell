-- | 체크리스트 도메인: 카탈로그(항목 목록)에 의존하는 순수 규칙
--   (전체 항목 수, 알 수 없는 key 정리). 웹/DB를 모른다.
--
--   항목 정본은 이제 DB(@checklist_items@)에 있으므로, 이 모듈의 함수들은
--   카탈로그를 인자로 받아 동작한다 (하드코딩하지 않는다).
module Luck.Domain.Checklist
    ( catalogKeys
    , sanitize
    , total
    ) where

import qualified Data.Set   as Set
import           Data.Text  (Text)
import           Luck.Types (CatalogItem (..))

-- | 유효한 항목 key 집합 (저장 시 알 수 없는 key를 걸러내기 위함).
catalogKeys :: [CatalogItem] -> Set.Set Text
catalogKeys = Set.fromList . map ciKey

-- | 전체 일별 항목 수 (달성률 계산용).
total :: [CatalogItem] -> Int
total = length

-- | 알 수 없는 key 제거 + 중복 제거 (현재 카탈로그 기준).
sanitize :: [CatalogItem] -> [Text] -> [Text]
sanitize cat xs =
  Set.toList (Set.intersection (catalogKeys cat) (Set.fromList xs))
