{-# LANGUAGE ScopedTypeVariables #-}

module Main (main) where

import Test.Hspec
import Test.QuickCheck

import LlmSafe.Client (mockCallLlm)
import LlmSafe.Pipeline (classifyPopulation, formatAnswer)
import LlmSafe.Types
  ( Confidence (..)
  , LlmError (..)
  , mkVerified
  , unVerified
  )
import LlmSafe.Verify
  ( parseIntFromText
  , verify
  , verifyByConsensus
  , verifyConfidence
  , verifyWith
  )

main :: IO ()
main = hspec $ do
  describe "LlmSafe.Types" $ do
    describe "Verified" $ do
      it "unVerified로 값을 꺼낼 수 있다" $
        unVerified (mkVerified 42) `shouldBe` (42 :: Int)

      it "mkVerified로 생성한 값은 동등하다" $
        mkVerified "hello" `shouldBe` mkVerified "hello"

    describe "Confidence" $ do
      it "High > Medium > Low 순서로 비교된다" $ do
        High > Medium `shouldBe` True
        Medium > Low `shouldBe` True
        High > Low `shouldBe` True

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
      it "신뢰도가 충분하면 통과한다" $ do
        let resp = mockCallLlm High "m" "content"
        verifyConfidence Medium resp `shouldBe` Right (mkVerified "content")

      it "신뢰도가 부족하면 LowConfidence를 반환한다" $ do
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
      it "과반수가 일치하면 합의에 도달한다" $ do
        let responses =
              [ mockCallLlm High "m" "950"
              , mockCallLlm High "m" "950"
              , mockCallLlm High "m" "1000"
              ]
        verifyByConsensus parseIntFromText responses
          `shouldBe` Right (mkVerified 950)

      it "과반수가 없으면 ConsensusNotReached를 반환한다" $ do
        let responses =
              [ mockCallLlm High "m" "100"
              , mockCallLlm High "m" "200"
              , mockCallLlm High "m" "300"
              ]
        verifyByConsensus parseIntFromText responses
          `shouldSatisfy` isConsensusNotReached

      it "빈 응답 목록은 ConsensusNotReached를 반환한다" $
        verifyByConsensus parseIntFromText []
          `shouldBe` Left (ConsensusNotReached "응답 없음")

    describe "parseIntFromText" $ do
      it "숫자가 포함된 텍스트에서 정수를 추출한다" $ do
        parseIntFromText "약 950만 명" `shouldBe` Right 950
        parseIntFromText "123" `shouldBe` Right 123

      it "숫자가 없으면 Left를 반환한다" $
        parseIntFromText "숫자 없음" `shouldSatisfy` isLeft

  describe "LlmSafe.Pipeline" $ do
    describe "classifyPopulation" $ do
      it "1000 초과이면 대도시로 분류한다" $
        classifyPopulation (mkVerified 1500)
          `shouldBe` "대도시 (인구 1500만)"

      it "100 초과 1000 이하이면 중도시로 분류한다" $
        classifyPopulation (mkVerified 350)
          `shouldBe` "중도시 (인구 350만)"

      it "100 이하이면 소도시로 분류한다" $
        classifyPopulation (mkVerified 50)
          `shouldBe` "소도시 (인구 50만)"

    describe "formatAnswer" $ do
      it "검증된 문자열에 접두사를 붙인다" $
        formatAnswer (mkVerified "답변")
          `shouldBe` "[검증됨] 답변"

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

-- | 헬퍼: Left가 ParseError인지 확인
isParseError :: Either LlmError a -> Bool
isParseError (Left (ParseError _)) = True
isParseError _ = False

-- | 헬퍼: Left가 ConsensusNotReached인지 확인
isConsensusNotReached :: Either LlmError a -> Bool
isConsensusNotReached (Left (ConsensusNotReached _)) = True
isConsensusNotReached _ = False

-- | 헬퍼: Either가 Left인지 확인
isLeft :: Either a b -> Bool
isLeft (Left _) = True
isLeft (Right _) = False
