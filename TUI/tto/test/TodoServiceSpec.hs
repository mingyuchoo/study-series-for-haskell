{-# LANGUAGE OverloadedStrings #-}

module TodoServiceSpec
    ( spec
    ) where

import qualified DB
import           TodoService

import           Flow       ((<|))
import           Test.Hspec

-- | 테스트용 TodoRow 헬퍼
mkTodoRow :: DB.TodoId -> String -> String -> DB.TodoRow
mkTodoRow tid action status =
    DB.TodoRow
        { DB.todoId = tid
        , DB.todoAction = action
        , DB.todoStatus = status
        , DB.todoCreatedAt = "2025-01-01 00:00"
        , DB.todoSubject = Nothing
        , DB.todoIndirectObject = Nothing
        , DB.todoDirectObject = Nothing
        , DB.todoStatusChangedAt = Nothing
        }

spec :: Spec
spec = do
  describe "findTodoById" <| do
    let rows =
            [ mkTodoRow 1 "할 일 1" "registered"
            , mkTodoRow 2 "할 일 2" "in_progress"
            , mkTodoRow 3 "할 일 3" "completed"
            ]

    it "존재하는 ID로 Todo를 찾아야 함" <| do
      case findTodoById 1 rows of
        Just row -> DB.todoAction row `shouldBe` "할 일 1"
        Nothing  -> expectationFailure "Todo를 찾지 못함"

    it "중간 ID로 Todo를 찾아야 함" <| do
      case findTodoById 2 rows of
        Just row -> DB.todoAction row `shouldBe` "할 일 2"
        Nothing  -> expectationFailure "Todo를 찾지 못함"

    it "마지막 ID로 Todo를 찾아야 함" <| do
      case findTodoById 3 rows of
        Just row -> DB.todoStatus row `shouldBe` "completed"
        Nothing  -> expectationFailure "Todo를 찾지 못함"

    it "존재하지 않는 ID는 Nothing을 반환해야 함" <| do
      findTodoById 999 rows `shouldBe` Nothing

    it "빈 리스트에서 Nothing을 반환해야 함" <| do
      findTodoById 1 [] `shouldBe` Nothing

    it "음수 ID도 처리해야 함" <| do
      findTodoById (-1) rows `shouldBe` Nothing

  describe "strip" <| do
    it "앞뒤 공백을 제거해야 함" <| do
      strip "  hello  " `shouldBe` "hello"

    it "내부 연속 공백을 하나로 축소해야 함" <| do
      strip "hello   world" `shouldBe` "hello world"

    it "빈 문자열은 빈 문자열을 반환해야 함" <| do
      strip "" `shouldBe` ""

    it "공백만 있는 문자열은 빈 문자열을 반환해야 함" <| do
      strip "   " `shouldBe` ""

    it "한글 문자열의 공백도 정리해야 함" <| do
      strip "  안녕  하세요  " `shouldBe` "안녕 하세요"

  describe "normalizeField" <| do
    it "Nothing은 Nothing을 반환해야 함" <| do
      normalizeField Nothing `shouldBe` Nothing

    it "빈 문자열은 Nothing으로 변환해야 함" <| do
      normalizeField (Just "") `shouldBe` Nothing

    it "공백만 있는 문자열은 Nothing으로 변환해야 함" <| do
      normalizeField (Just "   ") `shouldBe` Nothing

    it "정상 문자열은 trim된 Just를 반환해야 함" <| do
      normalizeField (Just "  hello  ") `shouldBe` Just "hello"

    it "한글 문자열도 정규화해야 함" <| do
      normalizeField (Just "  할 일  ") `shouldBe` Just "할 일"
