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
      -- * 파이프라인 (실제 LLM 호출)
    , consensusPipeline
    , distributionAnalysisPipeline
    , populationPipeline
      -- * 파이프라인 (주입 가능한 호출 함수 — 테스트용)
    , consensusPipelineWith
    , distributionAnalysisPipelineWith
    , populationPipelineWith
    ) where

import           LlmSafe.Client (callLlm, callLlmN)
import           LlmSafe.Types  (LlmConfig (..), LlmError, LlmResponse (..),
                                 Verified, renderLlmError, unVerified)
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
populationPipeline config logger =
  populationPipelineWith (callLlm config logger) logger

-- | LLM 호출 함수를 주입받는 'populationPipeline' 변형. 테스트에 사용한다.
populationPipelineWith
  :: (String -> IO (LlmResponse String))
  -- ^ LLM 호출 함수 (프롬프트 → 응답)
  -> (String -> IO ())
  -- ^ 로거
  -> String
  -- ^ 도시명
  -> IO (Either LlmError String)
populationPipelineWith callFn logger cityName = do
  -- [1단계] 비결정적 영역: LLM 호출
  logger "=== 1단계: LLM 호출 (비결정적) ==="
  response <- callFn ("'" <> cityName <> "'의 인구를 만 단위 정수로만 답하세요.")

  -- [2단계] 경계: 검증 관문
  logger "=== 2단계: 검증 관문 (비결정적 → 결정적) ==="
  let verified = verifyWith parseIntFromText (> 0) response

  case verified of
    Left err -> do
      logger $ renderLlmError err
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
consensusPipeline config logger =
  consensusPipelineWith (callLlmN config logger) logger

-- | LLM 호출 함수를 주입받는 'consensusPipeline' 변형. 테스트에 사용한다.
consensusPipelineWith
  :: (Int -> String -> IO [LlmResponse String])
  -- ^ N번 LLM 호출 함수 (횟수, 프롬프트 → 응답 목록)
  -> (String -> IO ())
  -- ^ 로거
  -> Int
  -- ^ 호출 횟수
  -> String
  -- ^ 도시명
  -> IO (Either LlmError String)
consensusPipelineWith callFn logger n cityName = do
  logger $ "=== 합의 기반 파이프라인 (" <> show n <> "회 호출) ==="
  let prompt = "'" <> cityName <> "'의 인구를 만 단위 정수로만 답하세요."
  responses <- callFn n prompt
  let verified = verifyByConsensus parseIntFromText responses
  case verified of
    Left err -> pure $ Left err
    Right v  -> pure $ Right (classifyPopulation v)

-- | 분포 분석 파이프라인: N번 호출 결과를 LLM이 직접 분포 분석하여 결정.
--
--   단순 다수결 대신, LLM이 여러 응답의 분포를 해석하고
--   가장 신뢰할 수 있는 값을 추론한다. 형식 불일치
--   ("950만", "9500000", "약 950") 도 LLM이 정규화한다.
distributionAnalysisPipeline
  :: LlmConfig -> (String -> IO ()) -> Int -> String -> IO (Either LlmError String)
distributionAnalysisPipeline config logger =
  distributionAnalysisPipelineWith (callLlmN config logger) (callLlm config logger) logger

-- | LLM 호출 함수를 주입받는 'distributionAnalysisPipeline' 변형. 테스트에 사용한다.
distributionAnalysisPipelineWith
  :: (Int -> String -> IO [LlmResponse String])
  -- ^ N번 LLM 호출 함수
  -> (String -> IO (LlmResponse String))
  -- ^ 분포 분석용 단일 LLM 호출 함수
  -> (String -> IO ())
  -- ^ 로거
  -> Int
  -- ^ 호출 횟수
  -> String
  -- ^ 도시명
  -> IO (Either LlmError String)
distributionAnalysisPipelineWith callFn analysisFn logger n cityName = do
  logger $ "=== 분포 분석 파이프라인 (" <> show n <> "회 호출) ==="

  -- [1단계] 비결정적 영역: N개 병렬 LLM 호출
  logger "=== 1단계: N개 에이전트 병렬 호출 (비결정적) ==="
  let prompt = "'" <> cityName <> "'의 인구를 만 단위 정수로만 답하세요."
  responses <- callFn n prompt

  -- [2단계] 메타 프롬프트 구성 + LLM 분포 분석 호출 (비결정적)
  logger "=== 2단계: LLM 분포 분석 호출 (비결정적) ==="
  let numbered = zipWith
        (\i r -> "  " <> show (i :: Int) <> ". " <> rawContent r)
        [1 ..] responses
      metaPrompt =
        "다음은 '" <> cityName <> "'의 인구에 대한 "
          <> show n <> "개의 LLM 응답입니다:\n"
          <> unlines numbered
          <> "\n이 응답들의 분포를 분석하여, 가장 신뢰할 수 있는 값을 "
          <> "만 단위 정수 하나로만 답하세요. 다른 설명 없이 숫자만 출력하세요."
  logger $ "분포 분석 입력 응답 수: " <> show (length responses)
  analysisResponse <- analysisFn metaPrompt
  logger $ "분포 분석 결과: " <> rawContent analysisResponse

  -- [3단계] 경계: 검증 관문 (비결정적 → 결정적)
  logger "=== 3단계: 검증 관문 (비결정적 → 결정적) ==="
  let verified = verifyWith parseIntFromText (> 0) analysisResponse
  case verified of
    Left err -> do
      logger $ renderLlmError err
      pure $ Left err
    Right v -> do
      -- [4단계] 결정적 영역: 순수 함수 적용
      logger "=== 4단계: 결정적 처리 ==="
      let result = classifyPopulation v
      logger $ "결과: " <> result
      pure $ Right result
