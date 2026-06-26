-- | 체크리스트 도메인: 항목 정본(catalog)과 그에 의존하는 순수 규칙
--   (전체 항목 수, 알 수 없는 key 정리). 웹/DB를 모른다.
module Luck.Domain.Checklist
    ( catalog
    , catalogKeys
    , sanitize
    , total
    ) where

import qualified Data.Set   as Set
import           Data.Text  (Text)
import           Luck.Types (CatalogItem (..))

-- | 일별 체크리스트 항목 (서버 측 정본).
catalog :: [CatalogItem]
catalog =
  [ CatalogItem "d1" "오늘 연락할 사람 한 명 정하고 연락하기 (오랜만인 사람 우선)"
  , CatalogItem "d2" "평소와 다른 선택 한 가지 하기 (다른 길, 새 가게, 새 메뉴)"
  , CatalogItem "d3" "떠오른 직감 하나를 메모해 두기"
  , CatalogItem "d4" "마감과 목표에서 잠시 벗어나 '다른 가능성은 없나' 한 번 묻기"
  , CatalogItem "d5" "잠들기 전 오늘 좋았던 일 세 가지 적기"
  ]

-- | 유효한 항목 key 집합 (저장 시 알 수 없는 key를 걸러내기 위함).
catalogKeys :: Set.Set Text
catalogKeys = Set.fromList (map ciKey catalog)

-- | 전체 일별 항목 수 (달성률 계산용).
total :: Int
total = length catalog

-- | 알 수 없는 key 제거 + 중복 제거.
sanitize :: [Text] -> [Text]
sanitize xs = Set.toList (Set.intersection catalogKeys (Set.fromList xs))
