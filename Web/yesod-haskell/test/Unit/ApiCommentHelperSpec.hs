{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}

-- | [REQ-T001, REQ-F004] ApiComment 헬퍼 함수 단위 테스트
--
-- 이 테스트는 다음 요구사항을 검증합니다:
--   - REQ-F004: 댓글 CRUD - JSON 파싱 및 직렬화 로직
module Unit.ApiCommentHelperSpec (spec) where

import Test.Hspec
import Handler.ApiComment (parseCommentInput, commentEntityToJson)
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
spec = describe "Handler.ApiComment helpers" $ do

    describe "parseCommentInput" $ do
        it "유효한 JSON에서 content를 파싱한다" $ do
            let json = object ["content" .= ("댓글 내용" :: String)]
            parseCommentInput json `shouldBe` Just "댓글 내용"

        it "content가 누락되면 Nothing을 반환한다" $ do
            let json = object []
            parseCommentInput json `shouldBe` Nothing

        it "잘못된 JSON 타입이면 Nothing을 반환한다" $ do
            parseCommentInput (Array mempty) `shouldBe` Nothing

    describe "commentEntityToJson" $ do
        it "Entity Comment를 JSON으로 변환하면 필수 필드를 포함한다" $ do
            let cid = toSqlKey 1 :: CommentId
                pid = toSqlKey 2 :: PostId
                uid = toSqlKey 3 :: UserId
                comment = Comment "댓글 내용" pid uid testTime
                entity = Entity cid comment
                result = commentEntityToJson entity
            case result of
                Object obj -> do
                    member "id" obj `shouldBe` True
                    member "content" obj `shouldBe` True
                    member "postId" obj `shouldBe` True
                    member "authorId" obj `shouldBe` True
                    member "createdAt" obj `shouldBe` True
                _ -> expectationFailure "JSON 객체가 아님"
