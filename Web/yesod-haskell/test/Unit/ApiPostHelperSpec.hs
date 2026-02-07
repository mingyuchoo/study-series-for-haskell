{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}

-- | [REQ-T001, REQ-F003] ApiPost 헬퍼 함수 단위 테스트
--
-- 이 테스트는 다음 요구사항을 검증합니다:
--   - REQ-F003: 포스트 CRUD - JSON 파싱 및 직렬화 로직
module Unit.ApiPostHelperSpec (spec) where

import Test.Hspec
import Handler.ApiPost (parsePostInput, postToJson, entityToJson)
import Model

import Data.Aeson (Value(..), object, (.=))
import Data.Aeson.KeyMap (member)
import Data.Time (UTCTime(..))
import Data.Time.Calendar (fromGregorian)
import Database.Persist (Entity(..))
import Database.Persist.Sql (toSqlKey)

-- | 테스트용 고정 시각
testTime :: UTCTime
testTime = UTCTime (fromGregorian 2026 1 1) 0

spec :: Spec
spec = describe "Handler.ApiPost helpers" $ do

    describe "parsePostInput" $ do
        it "유효한 JSON에서 title, content를 파싱한다" $ do
            let json = object ["title" .= ("제목" :: String), "content" .= ("본문" :: String)]
            parsePostInput json `shouldBe` Just ("제목", "본문")

        it "title이 누락되면 Nothing을 반환한다" $ do
            let json = object ["content" .= ("본문" :: String)]
            parsePostInput json `shouldBe` Nothing

        it "content가 누락되면 Nothing을 반환한다" $ do
            let json = object ["title" .= ("제목" :: String)]
            parsePostInput json `shouldBe` Nothing

        it "빈 객체이면 Nothing을 반환한다" $ do
            let json = object []
            parsePostInput json `shouldBe` Nothing

        it "배열 등 잘못된 JSON 타입이면 Nothing을 반환한다" $ do
            parsePostInput (Array mempty) `shouldBe` Nothing

    describe "postToJson" $ do
        it "Post를 JSON으로 변환하면 필수 필드를 포함한다" $ do
            let pid = toSqlKey 1 :: PostId
                uid = toSqlKey 2 :: UserId
                post = Post "제목" "본문" uid testTime testTime
                result = postToJson pid post
            case result of
                Object obj -> do
                    member "id" obj `shouldBe` True
                    member "title" obj `shouldBe` True
                    member "content" obj `shouldBe` True
                    member "authorId" obj `shouldBe` True
                    member "createdAt" obj `shouldBe` True
                    member "updatedAt" obj `shouldBe` True
                _ -> expectationFailure "JSON 객체가 아님"

    describe "entityToJson" $ do
        it "Entity Post를 JSON으로 변환한다" $ do
            let pid = toSqlKey 1 :: PostId
                uid = toSqlKey 2 :: UserId
                post = Post "제목" "본문" uid testTime testTime
                entity = Entity pid post
                result = entityToJson entity
            case result of
                Object obj -> member "id" obj `shouldBe` True
                _ -> expectationFailure "JSON 객체가 아님"
