{-# LANGUAGE OverloadedStrings #-}

-- | 파이프라인 모듈 — 비결정성의 흐름을 추적하는 처리 체인.
--
--   타입 시그니처만으로 비결정성의 흐름이 보인다:
--
--   @
--   String → IO (Either LlmError String)
--            ↑↑
--   IO = 부수 효과 (LLM 호출)
--   Either = 검증 실패 가능성
--   @
--
--   함수의 반환값이 'Right'이면,
--   그 안의 값은 검증을 통과한 결정적 결과이다.
module LlmSafe.Pipeline
    ( -- * 결정적 영역 (Verified 값만 받는 순수 함수)
      classifyPopulation
    , formatAnswer
      -- * 파이프라인 예시
    , consensusPipeline
    , populationPipeline
    ) where

import           LlmSafe.Client (callLlm, callLlmN)
import           LlmSafe.Types  (LlmConfig (..), LlmError, Verified, unVerified)
import           LlmSafe.Verify (parseIntFromText, verifyByConsensus,
                                 verifyWith)

--------------------------------------------------------------------------------
-- 결정적 영역: Verified 값만 받는 순수 함수들
-- 이 함수들은 LlmResponse를 직접 받을 수 없다 → 타입이 강제한다.
--------------------------------------------------------------------------------

-- | 인구 규모로 도시를 분류한다. 순수 함수.
--
--   'LlmResponse'를 넣으려 하면 컴파일 에러:
--
--   @
--   classifyPopulation response  -- 타입 에러!
--                                -- Expected: Verified Int
--                                -- Actual:   LlmResponse String
--   @
classifyPopulation :: Verified Int -> String
classifyPopulation v =
  let n = unVerified v
   in if n > 1000
        then "대도시 (인구 " <> show n <> "만)"
        else
          if n > 100
            then "중도시 (인구 " <> show n <> "만)"
            else "소도시 (인구 " <> show n <> "만)"

-- | 검증된 문자열을 포맷한다. 순수 함수.
formatAnswer :: Verified String -> String
formatAnswer v = "[검증됨] " <> unVerified v

--------------------------------------------------------------------------------
-- 파이프라인: 비결정적 호출 → 검증 → 결정적 처리
--------------------------------------------------------------------------------

-- | 도시 인구를 LLM에게 물어보고, 검증 후 결정적 처리를 수행하는 파이프라인.
--
--   'logger'를 통해 각 단계의 진행 상황을 출력한다.
populationPipeline :: LlmConfig -> (String -> IO ()) -> String -> IO (Either LlmError String)
populationPipeline config logger cityName = do
  -- [1단계] 비결정적 영역: LLM 호출
  logger "=== 1단계: LLM 호출 (비결정적) ==="
  response <- callLlm config logger ("'" <> cityName <> "'의 인구를 만 단위 정수로만 답하세요.")

  -- [2단계] 경계: 검증 관문
  logger "=== 2단계: 검증 관문 (비결정적 → 결정적) ==="
  let verified = verifyWith parseIntFromText (> 0) response

  case verified of
    Left err -> do
      logger $ "검증 실패: " <> show err
      pure $ Left err
    Right v -> do
      -- [3단계] 결정적 영역: 순수 함수 적용
      logger "=== 3단계: 결정적 처리 ==="
      let result = classifyPopulation v
      logger $ "결과: " <> result
      pure $ Right result

-- | 합의 기반 파이프라인: N번 호출하여 다수결로 결정.
--
--   Self-consistency 기법으로 비결정성을 줄인다.
consensusPipeline :: LlmConfig -> (String -> IO ()) -> Int -> String -> IO (Either LlmError String)
consensusPipeline config logger n cityName = do
  logger $ "=== 합의 기반 파이프라인 (" <> show n <> "회 호출) ==="
  let prompt = "'" <> cityName <> "'의 인구를 만 단위 정수로만 답하세요."

  -- N번 독립적으로 호출 (각각 비결정적)
  responses <- callLlmN config logger n prompt

  -- 합의로 비결정성을 줄인다
  let verified = verifyByConsensus parseIntFromText responses

  case verified of
    Left err -> pure $ Left err
    Right v  -> pure $ Right (classifyPopulation v)
