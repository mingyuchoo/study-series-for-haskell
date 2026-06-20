{-# LANGUAGE OverloadedStrings #-}

-- | 검증 관문 — 비결정적 → 결정적 경계.
--
--   이 모듈의 함수들만이 'Verified' 값을 생성할 수 있다.
--   LLM의 비결정적 응답을 결정적 영역으로 넘기려면
--   반드시 이 관문을 통과해야 한다.
module LlmSafe.Verify
  ( -- * 단순 검증
    verify
  , verifyConfidence
    -- * 구조적 검증 (파싱 + 검증)
  , verifyWith
    -- * 합의 기반 검증
  , verifyByConsensus
    -- * 유틸리티 파서
  , parseIntFromText
  ) where

import Data.List (group, maximumBy, sort)
import Data.Ord (comparing)

import LlmSafe.Types
  ( Confidence (..)
  , LlmError (..)
  , LlmResponse (..)
  , Verified
  , mkVerified
  )

-- | 단순 검증: 술어(predicate) 함수로 검증.
--
--   검증 실패 시 'Left', 성공 시 'Right' ('Verified' a).
--
--   >>> let resp = LlmResponse "hello" High "m" "h"
--   >>> verify (not . null) "빈 응답" resp
--   Right (Verified "hello")
verify
  :: (a -> Bool)
  -- ^ 검증 술어
  -> String
  -- ^ 실패 시 에러 메시지
  -> LlmResponse a
  -- ^ 원시 LLM 응답
  -> Either LlmError (Verified a)
verify predicate errorMsg response
  | predicate (rawContent response) = Right $ mkVerified (rawContent response)
  | otherwise = Left $ VerificationFailed errorMsg

-- | 신뢰도 기반 검증.
--
--   응답의 신뢰도가 요구 수준 이상일 때만 검증을 통과한다.
verifyConfidence
  :: Confidence
  -- ^ 최소 요구 신뢰도
  -> LlmResponse a
  -- ^ 원시 LLM 응답
  -> Either LlmError (Verified a)
verifyConfidence minConf response
  | confidence response >= minConf = Right $ mkVerified (rawContent response)
  | otherwise = Left $ LowConfidence (confidence response)

-- | 구조적 검증: 파싱 + 검증을 동시에 수행.
--
--   LLM의 자유 텍스트 출력을 구조화된 타입으로 변환하면서 검증한다.
--
--   >>> verifyWith parseIntFromText (> 0) resp
--   Right (Verified 950)
verifyWith
  :: (String -> Either String a)
  -- ^ 파서 (문자열 → 구조화된 타입)
  -> (a -> Bool)
  -- ^ 추가 검증 술어
  -> LlmResponse String
  -- ^ 원시 LLM 응답
  -> Either LlmError (Verified a)
verifyWith parser predicate response =
  case parser (rawContent response) of
    Left err -> Left $ ParseError err
    Right parsed
      | predicate parsed -> Right $ mkVerified parsed
      | otherwise -> Left $ VerificationFailed "파싱 성공했으나 검증 실패"

-- | 합의 기반 검증: 여러 응답에서 다수결로 결정적 결과를 추출.
--
--   Self-consistency 기법의 Haskell 구현.
--   n번 호출하여 가장 빈번한 응답이 과반수이면 검증 통과.
--
--   >>> verifyByConsensus parseIntFromText [r1, r2, r3]
--   Right (Verified 950)
verifyByConsensus
  :: (Ord a)
  => (String -> Either String a)
  -- ^ 각 응답의 파서
  -> [LlmResponse String]
  -- ^ 여러 번의 LLM 응답
  -> Either LlmError (Verified a)
verifyByConsensus _parser [] = Left $ ConsensusNotReached "응답 없음"
verifyByConsensus parser responses =
  let parsed = [p | r <- responses, Right p <- [parser (rawContent r)]]
      total = length responses
      grouped = group . sort $ parsed
   in case grouped of
        [] -> Left $ ConsensusNotReached "파싱 가능한 응답 없음"
        gs ->
          let (best, count) =
                maximumBy
                  (comparing snd)
                  [(headSafe g, length g) | g <- gs]
              threshold = total `div` 2 + 1
           in if count >= threshold
                then Right $ mkVerified best
                else
                  Left $
                    ConsensusNotReached $
                      "최빈 응답 "
                        <> show count
                        <> "/"
                        <> show total
                        <> " (과반수 "
                        <> show threshold
                        <> " 필요)"
  where
    -- group은 빈 리스트를 반환하지 않으므로 각 원소는 비어있지 않다
    headSafe (x : _) = x
    headSafe [] = error "LlmSafe.Verify: impossible — group never produces empty sublists"

-- | 텍스트에서 정수를 추출하는 유틸리티 파서.
--
--   문자열에서 숫자 문자만 추출하여 정수로 변환한다.
--   LLM 응답에서 숫자를 파싱할 때 사용한다.
--
--   >>> parseIntFromText "약 950만 명"
--   Right 950
parseIntFromText :: String -> Either String Int
parseIntFromText s =
  case reads (filter (`elem` ['0' .. '9']) s) of
    [(n, "")] -> Right n
    _         -> Left $ "정수를 파싱할 수 없음: " <> s
