{-# LANGUAGE ScopedTypeVariables #-}

module Main
    ( main
    ) where

import           Control.Exception  (SomeException, try)

import           LlmSafe.Client     (mockCallLlm)
import           LlmSafe.Pipeline   (classifyPopulation, consensusPipelineWith,
                                     distributionAnalysisPipelineWith,
                                     formatAnswer, populationPipelineWith)
import           LlmSafe.Types      (Confidence (..), LlmConfig (..),
                                     LlmError (..), LlmResponse (..),
                                     defaultConfig, mkVerified, renderLlmError,
                                     unVerified)
import           LlmSafe.Verify     (parseIntFromText, verify,
                                     verifyByConsensus, verifyConfidence,
                                     verifyWith)

import           System.Environment (setEnv, unsetEnv)

import           Test.Hspec
import           Test.QuickCheck

main :: IO ()
main = hspec $ do

  -- =========================================================================
  -- LlmSafe.Types
  -- =========================================================================
  describe "LlmSafe.Types" $ do

    describe "Verified" $ do
      it "unVerified로 값을 꺼낼 수 있다" $
        unVerified (mkVerified 42) `shouldBe` (42 :: Int)

      it "mkVerified로 생성한 값은 동등하다" $
        mkVerified "hello" `shouldBe` mkVerified "hello"

    describe "Confidence" $ do
      it "High > Medium > Low 순서로 비교된다" $ do
        (High > Medium) `shouldBe` True
        (Medium > Low)  `shouldBe` True
        (High > Low)    `shouldBe` True

    describe "LlmResponse" $ do
      let r = mockCallLlm Medium "model-x" "output"
      it "rawContent 필드가 올바르다" $ rawContent r `shouldBe` "output"
      it "confidence 필드가 올바르다" $ confidence r `shouldBe` Medium
      it "modelId 필드가 올바르다"    $ modelId r    `shouldBe` "model-x"
      it "promptHash 필드가 올바르다" $ promptHash r `shouldBe` "6"
      it "동일 값끼리 동등하다"       $ r `shouldBe` r

    describe "LlmError 동등성" $ do
      it "VerificationFailed" $ VerificationFailed "a" `shouldBe` VerificationFailed "a"
      it "ConsensusNotReached" $ ConsensusNotReached "a" `shouldBe` ConsensusNotReached "a"
      it "ParseError"          $ ParseError "a"          `shouldBe` ParseError "a"
      it "RetryExhausted"      $ RetryExhausted 3        `shouldBe` RetryExhausted 3
      it "LowConfidence"       $ LowConfidence High      `shouldBe` LowConfidence High

    describe "renderLlmError" $ do
      it "VerificationFailed 메시지를 렌더링한다" $
        renderLlmError (VerificationFailed "이유") `shouldBe` "검증 실패: 이유"

      it "ConsensusNotReached 메시지를 렌더링한다" $
        renderLlmError (ConsensusNotReached "이유") `shouldBe` "합의 실패: 이유"

      it "ParseError 메시지를 렌더링한다" $
        renderLlmError (ParseError "이유") `shouldBe` "파싱 오류: 이유"

      it "RetryExhausted 횟수를 렌더링한다" $
        renderLlmError (RetryExhausted 5) `shouldBe` "재시도 초과: 5회"

      it "LowConfidence 신뢰도를 렌더링한다" $
        renderLlmError (LowConfidence Low) `shouldBe` "신뢰도 부족: Low"

    describe "defaultConfig" $ do
      it "환경 변수에서 설정을 읽는다" $ do
        setEnv "AZURE_OPENAI_ENDPOINT"    "https://example.com"
        setEnv "AZURE_OPENAI_API_KEY"     "test-key"
        setEnv "AZURE_OPENAI_DEPLOYMENT"  "my-model"
        setEnv "AZURE_OPENAI_API_VERSION" "2024-01-01"
        setEnv "LLM_CONSENSUS_COUNT"      "7"
        cfg <- defaultConfig
        configEndpoint       cfg `shouldBe` "https://example.com"
        configApiKey         cfg `shouldBe` "test-key"
        configModelId        cfg `shouldBe` "my-model"
        configApiVersion     cfg `shouldBe` "2024-01-01"
        configConsensusCount cfg `shouldBe` 7

      it "선택적 환경 변수가 없으면 기본값을 사용한다" $ do
        setEnv   "AZURE_OPENAI_ENDPOINT" "https://example.com"
        setEnv   "AZURE_OPENAI_API_KEY"  "test-key"
        unsetEnv "AZURE_OPENAI_DEPLOYMENT"
        unsetEnv "AZURE_OPENAI_API_VERSION"
        unsetEnv "LLM_CONSENSUS_COUNT"
        cfg <- defaultConfig
        configModelId        cfg `shouldBe` "gpt-5-mini"
        configApiVersion     cfg `shouldBe` "2024-12-01-preview"
        configConsensusCount cfg `shouldBe` 3
        configMaxRetries     cfg `shouldBe` 3
        configMinConfidence  cfg `shouldBe` Medium

      it "필수 환경 변수(ENDPOINT)가 없으면 예외를 던진다" $ do
        unsetEnv "AZURE_OPENAI_ENDPOINT"
        result <- try defaultConfig :: IO (Either SomeException LlmConfig)
        result `shouldSatisfy` isLeft

      it "필수 환경 변수(API_KEY)가 없으면 예외를 던진다" $ do
        setEnv   "AZURE_OPENAI_ENDPOINT" "https://example.com"
        unsetEnv "AZURE_OPENAI_API_KEY"
        result <- try defaultConfig :: IO (Either SomeException LlmConfig)
        result `shouldSatisfy` isLeft

  -- =========================================================================
  -- LlmSafe.Verify
  -- =========================================================================
  describe "LlmSafe.Verify" $ do

    describe "verify" $ do
      let resp = mockCallLlm High "test-model" "hello world"

      it "술어를 만족하면 Right (Verified a)를 반환한다" $
        verify (not . null) "빈 응답" resp
          `shouldBe` Right (mkVerified "hello world")

      it "술어를 만족하지 못하면 Left VerificationFailed를 반환한다" $
        verify null "빈 응답이 아님" resp
          `shouldBe` Left (VerificationFailed "빈 응답이 아님")

    describe "verifyConfidence" $ do
      it "신뢰도가 높으면 통과한다 (High >= Medium)" $ do
        let resp = mockCallLlm High "m" "content"
        verifyConfidence Medium resp `shouldBe` Right (mkVerified "content")

      it "신뢰도가 정확히 같으면 통과한다 (Medium >= Medium)" $ do
        let resp = mockCallLlm Medium "m" "content"
        verifyConfidence Medium resp `shouldBe` Right (mkVerified "content")

      it "신뢰도가 부족하면 LowConfidence를 반환한다 (Low < Medium)" $ do
        let resp = mockCallLlm Low "m" "content"
        verifyConfidence Medium resp `shouldBe` Left (LowConfidence Low)

    describe "verifyWith" $ do
      it "파싱 + 검증 모두 통과하면 Verified를 반환한다" $ do
        let resp = mockCallLlm High "m" "인구 950만"
        verifyWith parseIntFromText (> 0) resp
          `shouldBe` Right (mkVerified 950)

      it "파싱 실패 시 ParseError를 반환한다" $ do
        let resp = mockCallLlm High "m" "숫자 없음"
        verifyWith parseIntFromText (> 0) resp
          `shouldSatisfy` isParseError

      it "파싱 성공이지만 검증 실패 시 VerificationFailed를 반환한다" $ do
        let resp = mockCallLlm High "m" "0"
        verifyWith parseIntFromText (> 0) resp
          `shouldBe` Left (VerificationFailed "파싱 성공했으나 검증 실패")

    describe "verifyByConsensus" $ do
      it "과반수가 일치하면 합의에 도달한다 (2/3)" $ do
        let responses = [ mockCallLlm High "m" "950"
                        , mockCallLlm High "m" "950"
                        , mockCallLlm High "m" "1000"
                        ]
        verifyByConsensus parseIntFromText responses
          `shouldBe` Right (mkVerified 950)

      it "과반수가 없으면 ConsensusNotReached를 반환한다 (1/3 각각)" $ do
        let responses = [ mockCallLlm High "m" "100"
                        , mockCallLlm High "m" "200"
                        , mockCallLlm High "m" "300"
                        ]
        verifyByConsensus parseIntFromText responses
          `shouldSatisfy` isConsensusNotReached

      it "빈 응답 목록은 ConsensusNotReached를 반환한다" $
        verifyByConsensus parseIntFromText []
          `shouldBe` Left (ConsensusNotReached "응답 없음")

      it "모든 응답이 파싱 실패하면 ConsensusNotReached를 반환한다" $ do
        let responses = [ mockCallLlm High "m" "숫자없음"
                        , mockCallLlm High "m" "없음"
                        ]
        verifyByConsensus parseIntFromText responses
          `shouldBe` Left (ConsensusNotReached "파싱 가능한 응답 없음")

    describe "parseIntFromText" $ do
      it "숫자가 포함된 텍스트에서 정수를 추출한다" $ do
        parseIntFromText "약 950만 명" `shouldBe` Right 950
        parseIntFromText "123"         `shouldBe` Right 123

      it "숫자만 있는 문자열에서 정수를 추출한다" $
        parseIntFromText "42" `shouldBe` Right 42

      it "숫자가 없으면 Left를 반환한다" $
        parseIntFromText "숫자 없음" `shouldSatisfy` isLeft

      it "빈 문자열은 Left를 반환한다" $
        parseIntFromText "" `shouldSatisfy` isLeft

  -- =========================================================================
  -- LlmSafe.Pipeline
  -- =========================================================================
  describe "LlmSafe.Pipeline" $ do

    describe "classifyPopulation" $ do
      it "1000 초과이면 대도시로 분류한다" $
        classifyPopulation (mkVerified 1500) `shouldBe` "대도시 (인구 1500만)"

      it "정확히 1000이면 중도시로 분류한다 (경계값)" $
        classifyPopulation (mkVerified 1000) `shouldBe` "중도시 (인구 1000만)"

      it "100 초과 1000 이하이면 중도시로 분류한다" $
        classifyPopulation (mkVerified 350) `shouldBe` "중도시 (인구 350만)"

      it "정확히 100이면 소도시로 분류한다 (경계값)" $
        classifyPopulation (mkVerified 100) `shouldBe` "소도시 (인구 100만)"

      it "100 이하이면 소도시로 분류한다" $
        classifyPopulation (mkVerified 50) `shouldBe` "소도시 (인구 50만)"

    describe "formatAnswer" $ do
      it "검증된 문자열에 접두사를 붙인다" $
        formatAnswer (mkVerified "답변") `shouldBe` "[검증됨] 답변"

      it "빈 문자열에도 접두사를 붙인다" $
        formatAnswer (mkVerified "") `shouldBe` "[검증됨] "

    describe "populationPipelineWith" $ do
      let noLog = const (pure ())

      it "정상 응답이면 Right 결과를 반환한다" $ do
        let callFn _ = pure (mockCallLlm High "m" "950")
        result <- populationPipelineWith callFn noLog "서울"
        result `shouldBe` Right "중도시 (인구 950만)"

      it "파싱 실패 응답이면 Left ParseError를 반환한다" $ do
        let callFn _ = pure (mockCallLlm High "m" "숫자없음")
        result <- populationPipelineWith callFn noLog "서울"
        result `shouldSatisfy` isLeft

      it "검증 실패(0 이하) 응답이면 Left VerificationFailed를 반환한다" $ do
        let callFn _ = pure (mockCallLlm High "m" "0")
        result <- populationPipelineWith callFn noLog "서울"
        result `shouldSatisfy` isLeft

    describe "consensusPipelineWith" $ do
      let noLog = const (pure ())

      it "합의 성공 시 Right 결과를 반환한다" $ do
        let callFn _ _ = pure (replicate 3 (mockCallLlm High "m" "950"))
        result <- consensusPipelineWith callFn noLog 3 "서울"
        result `shouldBe` Right "중도시 (인구 950만)"

      it "합의 실패 시 Left ConsensusNotReached를 반환한다" $ do
        let responses = [ mockCallLlm High "m" "100"
                        , mockCallLlm High "m" "200"
                        , mockCallLlm High "m" "300"
                        ]
        let callFn _ _ = pure responses
        result <- consensusPipelineWith callFn noLog 3 "서울"
        result `shouldSatisfy` isLeft

      it "빈 응답 목록이면 Left를 반환한다" $ do
        let callFn _ _ = pure []
        result <- consensusPipelineWith callFn noLog 3 "서울"
        result `shouldSatisfy` isLeft

    describe "distributionAnalysisPipelineWith" $ do
      let noLog = const (pure ())

      it "분석 LLM이 유효한 정수를 반환하면 Right 결과를 반환한다" $ do
        let callFn _ _ = pure (replicate 3 (mockCallLlm High "m" "950"))
            analysisFn _ = pure (mockCallLlm High "m" "950")
        result <- distributionAnalysisPipelineWith callFn analysisFn noLog 3 "서울"
        result `shouldBe` Right "중도시 (인구 950만)"

      it "분석 LLM이 다양한 형식을 정규화한 결과를 반환한다" $ do
        let responses = [ mockCallLlm High "m" "950"
                        , mockCallLlm High "m" "약 950만"
                        , mockCallLlm High "m" "9500000"
                        ]
            callFn _ _ = pure responses
            -- 형식이 달라도 LLM이 950으로 정규화한다고 가정
            analysisFn _ = pure (mockCallLlm High "m" "950")
        result <- distributionAnalysisPipelineWith callFn analysisFn noLog 3 "서울"
        result `shouldBe` Right "중도시 (인구 950만)"

      it "분석 LLM이 파싱 불가 응답을 반환하면 Left ParseError를 반환한다" $ do
        let callFn _ _ = pure (replicate 3 (mockCallLlm High "m" "950"))
            analysisFn _ = pure (mockCallLlm High "m" "파싱불가응답")
        result <- distributionAnalysisPipelineWith callFn analysisFn noLog 3 "서울"
        result `shouldSatisfy` isParseError

      it "분석 LLM이 0 이하를 반환하면 Left VerificationFailed를 반환한다" $ do
        let callFn _ _ = pure (replicate 3 (mockCallLlm High "m" "950"))
            analysisFn _ = pure (mockCallLlm High "m" "0")
        result <- distributionAnalysisPipelineWith callFn analysisFn noLog 3 "서울"
        result `shouldSatisfy` isLeft

  -- =========================================================================
  -- QuickCheck 속성 기반 테스트
  -- =========================================================================
  describe "QuickCheck 속성" $ do

    it "verify는 항상 참인 술어에 대해 항상 Right를 반환한다" $
      property $ \s ->
        let resp = mockCallLlm High "m" (s :: String)
         in verify (const True) "err" resp == Right (mkVerified s)

    it "verify는 항상 거짓인 술어에 대해 항상 Left를 반환한다" $
      property $ \s ->
        let resp = mockCallLlm High "m" (s :: String)
         in isLeft (verify (const False) "err" resp)

    it "parseIntFromText . show는 양의 정수에 대해 항등 함수이다" $
      property $ \(Positive n) ->
        parseIntFromText (show (n :: Int)) == Right n

    it "classifyPopulation은 항상 비어있지 않은 문자열을 반환한다" $
      property $ \(n :: Int) ->
        not (null (classifyPopulation (mkVerified n)))

    it "renderLlmError는 항상 비어있지 않은 문자열을 반환한다" $
      property $ \s ->
        not (null (renderLlmError (ParseError (s :: String))))

    it "verifyConfidence는 High 신뢰도에 대해 어떤 최소 신뢰도에도 통과한다" $
      property $ \s ->
        let resp = mockCallLlm High "m" (s :: String)
         in not (isLeft (verifyConfidence Low resp))

    it "unVerified . mkVerified는 항등 함수이다" $
      property $ \(n :: Int) ->
        unVerified (mkVerified n) == n

-- =============================================================================
-- 헬퍼 함수
-- =============================================================================

isParseError :: Either LlmError a -> Bool
isParseError (Left (ParseError _)) = True
isParseError _                     = False

isConsensusNotReached :: Either LlmError a -> Bool
isConsensusNotReached (Left (ConsensusNotReached _)) = True
isConsensusNotReached _                              = False

isLeft :: Either a b -> Bool
isLeft (Left _) = True
isLeft _        = False
