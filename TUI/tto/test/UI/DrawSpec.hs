{-# LANGUAGE OverloadedStrings #-}

module UI.DrawSpec
    ( spec
    ) where

import           UI.Draw

import           Flow      ((<|))
import           Test.Hspec

spec :: Spec
spec = do
  describe "stringWidth" <| do
    it "ASCII 문자열의 너비를 계산해야 함" <| do
      stringWidth "hello" `shouldBe` 5

    it "빈 문자열의 너비는 0이어야 함" <| do
      stringWidth "" `shouldBe` 0

    it "한글 문자의 너비를 2로 계산해야 함" <| do
      stringWidth "가" `shouldBe` 2

    it "한글 문자열의 너비를 정확히 계산해야 함" <| do
      stringWidth "한글" `shouldBe` 4

    it "한글과 ASCII 혼합 문자열의 너비를 계산해야 함" <| do
      stringWidth "hello한글" `shouldBe` 9

    it "CJK 한자의 너비를 2로 계산해야 함" <| do
      stringWidth "漢" `shouldBe` 2

    it "전각 문자의 너비를 2로 계산해야 함" <| do
      stringWidth "\xFF01" `shouldBe` 2

  describe "truncateToWidth" <| do
    it "최대 너비 이하의 문자열은 그대로 반환해야 함" <| do
      truncateToWidth 10 "hello" `shouldBe` "hello"

    it "최대 너비를 초과하는 문자열을 잘라야 함" <| do
      truncateToWidth 3 "hello" `shouldBe` "hel"

    it "한글 문자열을 올바르게 잘라야 함" <| do
      truncateToWidth 4 "한글테스트" `shouldBe` "한글"

    it "한글이 잘리는 경계에서 안전하게 처리해야 함" <| do
      truncateToWidth 3 "한글" `shouldBe` "한"

    it "빈 문자열은 빈 문자열을 반환해야 함" <| do
      truncateToWidth 5 "" `shouldBe` ""

    it "너비 0이면 빈 문자열을 반환해야 함" <| do
      truncateToWidth 0 "hello" `shouldBe` ""

  describe "truncateWithEllipsis" <| do
    it "최대 너비 이하의 문자열은 그대로 반환해야 함" <| do
      truncateWithEllipsis 10 "hello" `shouldBe` "hello"

    it "초과 시 말줄임표를 추가해야 함" <| do
      truncateWithEllipsis 8 "hello world" `shouldBe` "hello..."

    it "최대 너비가 3 이하면 말줄임표만 반환해야 함" <| do
      truncateWithEllipsis 3 "hello" `shouldBe` "..."

    it "빈 문자열은 그대로 반환해야 함" <| do
      truncateWithEllipsis 5 "" `shouldBe` ""

    it "정확히 최대 너비인 문자열은 그대로 반환해야 함" <| do
      truncateWithEllipsis 5 "hello" `shouldBe` "hello"
