{-# LANGUAGE OverloadedStrings #-}

module UI.EventsSpec
    ( spec
    ) where

import           Test.Hspec
import           Flow             ((<|))
import           UI.Events

spec :: Spec
spec = do
  describe "trim" <| do
    it "앞뒤 공백을 제거해야 함" <| do
      trim "  hello  " `shouldBe` "hello"

    it "중간의 여러 공백을 하나로 줄여야 함" <| do
      trim "hello   world" `shouldBe` "hello world"

    it "빈 문자열은 빈 문자열을 반환해야 함" <| do
      trim "" `shouldBe` ""

    it "공백만 있는 문자열은 빈 문자열을 반환해야 함" <| do
      trim "   " `shouldBe` ""

    it "개행문자와 탭도 처리해야 함" <| do
      trim "\n\thello\t\n" `shouldBe` "hello"

    it "여러 줄의 공백을 처리해야 함" <| do
      trim "hello\n\n\nworld" `shouldBe` "hello world"

    it "탭과 공백이 섞인 경우를 처리해야 함" <| do
      trim "\t  hello  \t  world  \t" `shouldBe` "hello world"

    it "단일 단어는 그대로 반환해야 함" <| do
      trim "hello" `shouldBe` "hello"

    it "이미 정리된 문자열은 그대로 반환해야 함" <| do
      trim "hello world" `shouldBe` "hello world"

    it "한글 문자열의 공백도 처리해야 함" <| do
      trim "  안녕  하세요  " `shouldBe` "안녕 하세요"

    it "유니코드와 공백이 섞인 복합 문자열을 처리해야 함" <| do
      trim "  hello  세계  world  " `shouldBe` "hello 세계 world"

    it "단일 공백은 빈 문자열을 반환해야 함" <| do
      trim " " `shouldBe` ""
