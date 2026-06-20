-- | LLM 응답의 비결정성을 타입으로 격리하고,
--   검증된 결과만 결정적 영역으로 넘기는 아키텍처.
--
--   == 핵심 원칙
--
--   1. 비결정적 결과(LLM 응답)는 'LlmResponse' 타입으로 감싼다
--   2. 검증을 통과해야만 'Verified' 타입을 얻는다
--   3. 후속 처리 함수는 'Verified' 타입만 받는다
--   4. 비결정성의 경계가 타입 시그니처에 항상 드러난다
--
--   == 사용 예시
--
--   @
--   import LlmSafe
--
--   main :: IO ()
--   main = do
--     response <- callLlm defaultConfig "서울의 인구는?"
--     case verify (not . null) "빈 응답" response of
--       Left err -> print err
--       Right v  -> putStrLn (formatAnswer v)
--   @
module LlmSafe
  ( -- * 핵심 타입
    module LlmSafe.Types
    -- * LLM 호출 (비결정적 영역)
  , module LlmSafe.Client
    -- * 검증 관문 (비결정적 → 결정적 경계)
  , module LlmSafe.Verify
    -- * 파이프라인 및 결정적 처리
  , module LlmSafe.Pipeline
  ) where

import LlmSafe.Client
import LlmSafe.Pipeline
import LlmSafe.Types
import LlmSafe.Verify
