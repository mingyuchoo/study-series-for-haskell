module Main (main) where

import LlmSafe
  ( classifyPopulation
  , consensusPipeline
  , defaultConfig
  , populationPipeline
  )

-- | LLM 비결정성 관리 데모.
--
--   비결정적 LLM 응답이 타입 시스템에 의해 어떻게
--   격리·검증되는지 보여준다.
main :: IO ()
main = do
  putStrLn "╔══════════════════════════════════════════════════╗"
  putStrLn "║  LLM 비결정성 관리 — Haskell 타입 안전성 데모   ║"
  putStrLn "╚══════════════════════════════════════════════════╝"
  putStrLn ""

  -- 단일 호출 파이프라인
  putStrLn "── 단일 호출 파이프라인 ──────────────────────────"
  result1 <- populationPipeline defaultConfig "서울"
  putStrLn $ "최종 결과: " <> show result1
  putStrLn ""

  -- 합의 기반 파이프라인
  putStrLn "── 합의 기반 파이프라인 ──────────────────────────"
  result2 <- consensusPipeline defaultConfig 3 "부산"
  putStrLn $ "최종 결과: " <> show result2
  putStrLn ""

  -- 타입 안전성 설명
  putStrLn "────────────────────────────────────────────────────"
  putStrLn ""
  putStrLn "▶ 아래 코드는 컴파일 에러를 발생시킨다:"
  putStrLn "  response <- callLlm defaultConfig \"...\""
  putStrLn "  classifyPopulation response   -- 타입 에러!"
  putStrLn "                                -- Expected: Verified Int"
  putStrLn "                                -- Actual:   LlmResponse String"
  putStrLn ""
  putStrLn "▶ 비결정적 결과를 결정적 함수에 넣으려면"
  putStrLn "  반드시 verify/verifyWith/verifyByConsensus를 통과해야 한다."
  putStrLn "  이것이 타입이 강제하는 검증 관문이다."

  -- classifyPopulation은 Verified Int만 받는다는 것을 증명
  -- (이 줄은 타입 시그니처 확인용, 실제로는 호출하지 않음)
  let _ = classifyPopulation -- :: Verified Int -> String
  pure ()
