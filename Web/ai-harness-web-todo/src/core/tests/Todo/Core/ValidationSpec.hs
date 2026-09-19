{-# LANGUAGE OverloadedStrings #-}

-- | 값 객체 정규화와 입력 검증 규칙 검증입니다.
module Todo.Core.ValidationSpec (spec) where

import qualified Data.Set as Set
import qualified Data.Text as T
import Data.Time (addDays)
import Test.Hspec (Spec, describe, it, shouldBe)
import Todo.Core.Gen (fixedToday)
import Todo.Core.Types (ListId (..), Tag (..), Title (..))
import Todo.Core.Validation (
  ValidationError (..),
  maxTagLength,
  maxTitleLength,
  mkListId,
  mkTag,
  mkTags,
  mkTitle,
  validateDueOn,
 )

spec :: Spec
spec = describe "Todo.Core.Validation" $ do
  describe "mkTitle" $ do
    it "앞뒤 공백을 제거하고 내부 공백을 하나로 접는다" $
      mkTitle "  보고서   작성  " `shouldBe` Right (Title "보고서 작성")

    it "공백만 있는 제목을 거부한다" $
      mkTitle "   \t \n " `shouldBe` Left EmptyTitle

    it "최대 길이를 넘는 제목을 거부한다" $
      mkTitle (T.replicate (maxTitleLength + 1) "가")
        `shouldBe` Left (TitleTooLong (maxTitleLength + 1))

    it "최대 길이와 같은 제목은 허용한다" $
      fmap (T.length . unTitle) (mkTitle (T.replicate maxTitleLength "가"))
        `shouldBe` Right maxTitleLength

  describe "mkTag" $ do
    it "소문자로 정규화한다" $
      mkTag "  Work  " `shouldBe` Right (Tag "work")

    it "허용되지 않은 문자를 거부한다" $
      mkTag "work!" `shouldBe` Left (InvalidTagCharacter '!')

    it "하이픈과 밑줄을 허용한다" $
      mkTag "deep-work_2" `shouldBe` Right (Tag "deep-work_2")

    it "최대 길이를 넘는 태그를 거부한다" $
      mkTag (T.replicate (maxTagLength + 1) "a")
        `shouldBe` Left (TagTooLong (maxTagLength + 1))

  describe "mkTags" $ do
    it "정규화 후 중복을 하나로 합친다" $
      mkTags ["Work", "work", " WORK "]
        `shouldBe` Right (Set.fromList [Tag "work"])

    it "하나라도 잘못되면 전체를 거부한다" $
      mkTags ["work", "bad!"] `shouldBe` Left (InvalidTagCharacter '!')

  describe "mkListId" $ do
    it "태그와 같은 정규화 규칙을 사용한다" $
      mkListId " Home " `shouldBe` Right (ListId "home")

    it "빈 목록 이름을 거부한다" $
      mkListId "   " `shouldBe` Left EmptyListId

  describe "validateDueOn" $ do
    it "마감일이 없으면 통과한다" $
      validateDueOn fixedToday Nothing `shouldBe` Right Nothing

    it "오늘은 과거가 아니다" $
      validateDueOn fixedToday (Just fixedToday) `shouldBe` Right (Just fixedToday)

    it "어제는 거부한다" $
      let yesterday = addDays (-1) fixedToday
       in validateDueOn fixedToday (Just yesterday)
            `shouldBe` Left (DueDateInPast yesterday fixedToday)
