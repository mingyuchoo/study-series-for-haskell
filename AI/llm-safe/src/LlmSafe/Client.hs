{-# LANGUAGE OverloadedStrings #-}

-- | LLM API 호출 모듈 — 비결정적 영역.
--
--   이 모듈의 모든 함수는 'IO' 모나드 안에 있으므로,
--   타입 시그니처만으로 비결정성이 드러난다.
--
--   실제 HTTP 클라이언트 연동 시 이 모듈만 교체하면 된다.
module LlmSafe.Client
  ( -- * LLM 호출 (비결정적 영역)
    callLlm
  , callLlmWithRetry
  , callLlmN

    -- * 모의(Mock) 클라이언트
  , mockCallLlm
  ) where

import LlmSafe.Types
  ( Confidence (..)
  , LlmConfig (..)
  , LlmError (..)
  , LlmResponse (..)
  )

-- | LLM API 호출.
--
--   'IO' 모나드 안에 있으므로 비결정적임이 타입에 드러난다.
--   실제 구현에서는 HTTP 클라이언트로 API를 호출한다.
--
--   >>> response <- callLlm defaultConfig "서울의 인구는?"
--   >>> rawContent response
--   "서울의 인구는 약 950만 명입니다."
callLlm :: LlmConfig -> String -> IO (LlmResponse String)
callLlm config prompt = do
  -- 실제로는 여기서 HTTP 요청 발생
  -- 예시: response <- httpPost "https://api.anthropic.com/v1/messages" ...
  putStrLn $ "[LLM 호출] 모델: " <> configModelId config
  putStrLn $ "[LLM 호출] 프롬프트: " <> take 50 prompt <> "..."
  pure
    LlmResponse
      { rawContent = "서울의 인구는 약 950만 명입니다."
      , confidence = Medium
      , modelId = configModelId config
      , promptHash = show (length prompt)
      }

-- | 재시도가 포함된 LLM 호출.
--
--   신뢰도가 설정의 최소 요구 수준 미만이면 재시도한다.
--   최대 재시도 횟수를 초과하면 'RetryExhausted'를 반환한다.
callLlmWithRetry :: LlmConfig -> String -> IO (Either LlmError (LlmResponse String))
callLlmWithRetry config prompt = go (configMaxRetries config)
 where
  go 0 = pure $ Left (RetryExhausted (configMaxRetries config))
  go n = do
    response <- callLlm config prompt
    if confidence response < configMinConfidence config
      then do
        putStrLn $ "[재시도] 신뢰도 부족, 남은 횟수: " <> show (n - 1)
        go (n - 1)
      else pure $ Right response

-- | N번 독립적으로 LLM을 호출하여 응답 목록을 수집한다.
--
--   합의 기반 검증('LlmSafe.Verify.verifyByConsensus')의 입력으로 사용된다.
callLlmN :: LlmConfig -> Int -> String -> IO [LlmResponse String]
callLlmN config n prompt = sequence [callLlm config prompt | _ <- [1 .. n]]

-- | 모의 LLM 호출. 테스트용으로 순수한 응답을 생성한다.
--
--   >>> mockCallLlm High "test-model" "answer"
--   LlmResponse {rawContent = "answer", confidence = High, ...}
mockCallLlm :: Confidence -> String -> String -> LlmResponse String
mockCallLlm conf model content =
  LlmResponse
    { rawContent = content
    , confidence = conf
    , modelId = model
    , promptHash = show (length content)
    }
