{-# LANGUAGE OverloadedStrings #-}

module UI.DrawSpec
    ( spec
    ) where

import           UI.Draw

import qualified I18n

import           Flow      ((<|))
import           Test.Hspec

spec :: Spec
spec = do
  describe "charWidth" <| do
    it "ASCII 문자의 너비는 1이어야 함" <| do
      charWidth 'a' `shouldBe` 1
      charWidth 'Z' `shouldBe` 1
      charWidth '0' `shouldBe` 1

    it "한글 자모(U+1100-U+11FF)의 너비는 2이어야 함" <| do
      charWidth '\x1100' `shouldBe` 2
      charWidth '\x11FF' `shouldBe` 2

    it "한글 호환 자모(U+3130-U+318F)의 너비는 2이어야 함" <| do
      charWidth '\x3130' `shouldBe` 2
      charWidth '\x318F' `shouldBe` 2

    it "한글 음절(U+AC00-U+D7AF)의 너비는 2이어야 함" <| do
      charWidth '가' `shouldBe` 2
      charWidth '힣' `shouldBe` 2

    it "CJK 통합 한자(U+4E00-U+9FFF)의 너비는 2이어야 함" <| do
      charWidth '漢' `shouldBe` 2
      charWidth '\x4E00' `shouldBe` 2

    it "전각 문자(U+FF00-U+FFEF)의 너비는 2이어야 함" <| do
      charWidth '\xFF01' `shouldBe` 2
      charWidth '\xFF5E' `shouldBe` 2

    it "CJK 기호 및 구두점(U+3000-U+303F)의 너비는 2이어야 함" <| do
      charWidth '\x3000' `shouldBe` 2
      charWidth '\x3001' `shouldBe` 2

    it "공백 문자의 너비는 1이어야 함" <| do
      charWidth ' ' `shouldBe` 1

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

    it "복합 유니코드 문자열의 너비를 정확히 계산해야 함" <| do
      stringWidth "abc한글漢" `shouldBe` 9

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

    it "혼합 문자열에서 정확한 위치에서 잘라야 함" <| do
      truncateToWidth 5 "ab한글" `shouldBe` "ab한"

    it "정확히 맞는 너비는 전체 문자열을 반환해야 함" <| do
      truncateToWidth 4 "한글" `shouldBe` "한글"

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

    it "한글 문자열에 말줄임표를 추가해야 함" <| do
      truncateWithEllipsis 7 "한글테스트" `shouldBe` "한글..."

    it "최대 너비가 2일 때 말줄임표만 반환해야 함" <| do
      truncateWithEllipsis 2 "test" `shouldBe` "..."

    it "최대 너비가 1일 때 말줄임표만 반환해야 함" <| do
      truncateWithEllipsis 1 "test" `shouldBe` "..."

  describe "statusToIcon" <| do
    it "registered 상태의 아이콘을 반환해야 함" <| do
      statusToIcon "registered" `shouldBe` "[R] "

    it "in_progress 상태의 아이콘을 반환해야 함" <| do
      statusToIcon "in_progress" `shouldBe` "[P] "

    it "cancelled 상태의 아이콘을 반환해야 함" <| do
      statusToIcon "cancelled" `shouldBe` "[X] "

    it "completed 상태의 아이콘을 반환해야 함" <| do
      statusToIcon "completed" `shouldBe` "[✓] "

    it "알 수 없는 상태의 기본 아이콘을 반환해야 함" <| do
      statusToIcon "unknown" `shouldBe` "[ ] "

    it "빈 문자열의 기본 아이콘을 반환해야 함" <| do
      statusToIcon "" `shouldBe` "[ ] "

  describe "statusToAttrName" <| do
    it "registered 상태의 속성 이름을 반환해야 함" <| do
      statusToAttrName "registered" `shouldBe` "registered"

    it "in_progress 상태의 속성 이름을 반환해야 함" <| do
      statusToAttrName "in_progress" `shouldBe` "in_progress"

    it "cancelled 상태의 속성 이름을 반환해야 함" <| do
      statusToAttrName "cancelled" `shouldBe` "cancelled"

    it "completed 상태의 속성 이름을 반환해야 함" <| do
      statusToAttrName "completed" `shouldBe` "completed"

    it "알 수 없는 상태는 normal을 반환해야 함" <| do
      statusToAttrName "unknown" `shouldBe` "normal"

  describe "statusToDisplayText" <| do
    let statusMsgs = I18n.status I18n.defaultMessages

    it "registered 상태의 표시 텍스트를 반환해야 함" <| do
      statusToDisplayText statusMsgs "registered" `shouldBe` I18n.registered statusMsgs

    it "in_progress 상태의 표시 텍스트를 반환해야 함" <| do
      statusToDisplayText statusMsgs "in_progress" `shouldBe` I18n.in_progress statusMsgs

    it "cancelled 상태의 표시 텍스트를 반환해야 함" <| do
      statusToDisplayText statusMsgs "cancelled" `shouldBe` I18n.cancelled statusMsgs

    it "completed 상태의 표시 텍스트를 반환해야 함" <| do
      statusToDisplayText statusMsgs "completed" `shouldBe` I18n.completed statusMsgs

    it "알 수 없는 상태는 Unknown을 반환해야 함" <| do
      statusToDisplayText statusMsgs "unknown" `shouldBe` "Unknown"
