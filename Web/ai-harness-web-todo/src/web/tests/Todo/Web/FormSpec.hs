{-# LANGUAGE OverloadedStrings #-}

module Todo.Web.FormSpec (spec) where

import qualified Data.Set as Set
import Data.Text (Text)
import Data.Time (fromGregorian)
import Test.Hspec
import Todo.Core.Repository (NewTodo (..), TodoPatch (..), emptyPatch)
import Todo.Core.Types (ListId (..), Priority (..), Status (..), Tag (..), Title (..), defaultListId)
import Todo.Web.Form
import Todo.Web.Gen (fixedNow, fixedToday)

parseNew :: [(Text, Text)] -> Either FormError NewTodo
parseNew = parseNewTodo fixedNow fixedToday

spec :: Spec
spec = do
  describe "새 할 일 폼" $ do
    it "제목만으로 만들 수 있다" $
      fmap newTitle (parseNew [("title", "장보기")]) `shouldBe` Right (Title "장보기")

    it "제목이 없으면 거부한다" $
      parseNew [] `shouldBe` Left (MissingField "title")

    it "제목이 공백뿐이면 도메인 검증이 거부한다" $
      parseNew [("title", "   ")] `shouldSatisfy` isRejected

    it "목록을 비우면 기본 목록에 넣는다" $
      fmap newListId (parseNew [("title", "장보기")]) `shouldBe` Right defaultListId

    it "우선순위를 비우면 보통이다" $
      fmap newPriority (parseNew [("title", "장보기")]) `shouldBe` Right Normal

    it "알 수 없는 우선순위를 거부한다" $
      parseNew [("title", "장보기"), ("priority", "매우높음")]
        `shouldBe` Left (UnknownPriorityValue "매우높음")

    it "태그를 공백으로 나눈다" $
      fmap newTags (parseNew [("title", "장보기"), ("tags", "work home")])
        `shouldBe` Right (Set.fromList [Tag "work", Tag "home"])

    it "허용되지 않은 태그 문자를 도메인 검증이 거부한다" $
      parseNew [("title", "장보기"), ("tags", "wo!rk")] `shouldSatisfy` isRejected

    it "날짜 형식이 아니면 거부한다" $
      parseNew [("title", "장보기"), ("due", "내일")] `shouldBe` Left (MalformedDate "내일")

    it "과거 마감일을 도메인 검증이 거부한다" $
      parseNew [("title", "장보기"), ("due", "2020-01-01")] `shouldSatisfy` isRejected

    it "오늘 이후의 마감일을 받는다" $
      fmap newDueOn (parseNew [("title", "장보기"), ("due", "2026-09-01")])
        `shouldBe` Right (Just (fromGregorian 2026 9 1))

    it "생성 시각은 경계에서 주입한 값을 그대로 쓴다" $
      fmap newCreatedAt (parseNew [("title", "장보기")]) `shouldBe` Right fixedNow

  describe "수정 폼" $ do
    it "빈 폼은 아무것도 바꾸지 않는다" $
      parsePatch [] `shouldBe` Right emptyPatch

    it "제목만 바꾼다" $
      fmap patchTitle (parsePatch [("title", "고침")]) `shouldBe` Right (Just (Title "고침"))

    it "마감일 필드가 없으면 바꾸지 않는다" $
      fmap patchDueOn (parsePatch [("title", "고침")]) `shouldBe` Right Nothing

    it "마감일을 빈 값으로 보내면 제거한다" $
      -- HTML 폼은 빈 입력도 필드를 보냅니다. 화면에서 날짜를 비우는 것이 제거 요청입니다.
      fmap patchDueOn (parsePatch [("due", "")]) `shouldBe` Right (Just Nothing)

    it "마감일에 값이 있으면 그 값으로 바꾼다" $
      fmap patchDueOn (parsePatch [("due", "2026-12-25")])
        `shouldBe` Right (Just (Just (fromGregorian 2026 12 25)))

    it "수정에서는 과거 마감일을 막지 않는다" $
      -- 이미 지난 마감일을 가진 할 일의 제목만 고치는 것을 막지 않기 위해서이며
      -- api의 PATCH와 같습니다.
      fmap patchDueOn (parsePatch [("due", "2020-01-01")])
        `shouldBe` Right (Just (Just (fromGregorian 2020 1 1)))

    it "태그 필드를 비우면 태그를 모두 지운다" $
      fmap patchTags (parsePatch [("tags", "")]) `shouldBe` Right (Just Set.empty)

    it "목록 이름을 바꾼다" $
      fmap patchListId (parsePatch [("list", "home")]) `shouldBe` Right (Just (ListId "home"))

  describe "상태 변경 폼" $ do
    it "상태 이름을 읽는다" $
      parseStatusChange [("status", "done")] `shouldBe` Right Done

    it "상태가 없으면 거부한다" $
      parseStatusChange [] `shouldBe` Left (MissingField "status")

    it "알 수 없는 상태를 거부한다" $
      parseStatusChange [("status", "finished")] `shouldBe` Left (UnknownStatusValue "finished")

    it "표시 문구는 받지 않는다" $
      -- 화면에 보이는 말과 폼에 실리는 값은 다른 층입니다.
      parseStatusChange [("status", "진행 중")] `shouldBe` Left (UnknownStatusValue "진행 중")

  describe "오류 문구"
    $ it "미래 날짜 계산 없이 도메인 문구를 그대로 쓴다"
    $ renderFormError (MalformedDate "내일") `shouldBe` "날짜 형식이 아닙니다: 내일"

isRejected :: Either FormError a -> Bool
isRejected result = case result of
  Left (RejectedValue _) -> True
  _ -> False
