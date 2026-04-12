module Fuzzy
    ( filterItems
    , fuzzyMatchScore
    ) where
import           Data.List   (sortOn)
import qualified Data.Text   as T
import qualified Data.Vector as Vec

import           Flow        ((<|))

-- | 퍼지 매칭 점수 계산 함수 (Pure)
-- 쿼리와 텍스트를 비교하여 매칭 점수 반환
-- Nothing: 매칭 안됨, Just score: 매칭됨 (점수가 낮을수록 좋은 매칭)
fuzzyMatchScore :: T.Text -> T.Text -> Maybe Int
fuzzyMatchScore query text = go (T.toLower query) (T.toLower text) 0
  where
    -- | 재귀적으로 문자를 비교하며 갭(건너뛴 문자 수) 계산 (Pure)
    -- T.uncons를 사용하여 head/tail 이중 순회를 방지
    go q t gaps = case (T.uncons q, T.uncons t) of
      (Nothing, _)                       -> Just gaps
      (_, Nothing)                       -> Nothing
      (Just (qc, qr), Just (tc, tr))
        | qc == tc  -> go qr tr gaps
        | otherwise -> go q tr (gaps + 1)

-- | 파일 경로의 깊이(슬래시 개수) 계산 (Pure)
-- 정렬 시 얕은 경로 우선을 위해 사용
pathDepth :: T.Text -> Int
pathDepth t = T.count "/" t + T.count "\\" t

-- | 검색어로 아이템 필터링 및 점수순 정렬 (Pure)
-- 빈 쿼리면 전체 반환, 아니면 매칭되는 항목만 점수순 정렬
filterItems :: T.Text -> Vec.Vector T.Text -> Vec.Vector T.Text
filterItems query items
  | T.null query = items
  | otherwise    = Vec.fromList . map snd . sortOn fst <| scored
  where
    scored = [ ((score, pathDepth item), item)
             | item <- Vec.toList items
             , Just score <- [fuzzyMatchScore query item]
             ]
