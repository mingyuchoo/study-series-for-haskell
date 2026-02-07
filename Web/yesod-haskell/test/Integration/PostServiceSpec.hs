{-# LANGUAGE OverloadedStrings #-}

-- | [REQ-T001, REQ-F003] PostService 통합 테스트 — DB 레벨 CRUD 검증
--
-- 이 테스트는 다음 요구사항을 검증합니다:
--   - REQ-F003: 포스트 CRUD - 생성, 조회, 수정, 삭제 DB 로직
module Integration.PostServiceSpec (spec) where

import Test.Hspec
import TestFoundation (withApp, runTestDB)
import Model

import Control.Monad.IO.Class (liftIO)
import Data.Time (UTCTime(..), getCurrentTime)
import Database.Persist
import Database.Persist.Sql (SqlPersistT, toSqlKey)

-- | 테스트용 사용자 삽입 헬퍼
insertTestUser :: UTCTime -> SqlPersistT IO UserId
insertTestUser now = insert $ User "테스트유저" "test@example.com" "hashedpw" now

spec :: Spec
spec = withApp $ do

    describe "PostService — 포스트 CRUD" $ do

        it "포스트를 생성하고 조회할 수 있다" $ do
            now <- liftIO getCurrentTime
            runTestDB $ do
                uid <- insertTestUser now
                pid <- insert $ Post "제목" "본문" uid now now
                mPost <- get pid
                liftIO $ fmap postTitle mPost `shouldBe` Just "제목"
                liftIO $ fmap postContent mPost `shouldBe` Just "본문"
                liftIO $ fmap postAuthorId mPost `shouldBe` Just uid

        it "모든 포스트를 최신순으로 조회한다" $ do
            now <- liftIO getCurrentTime
            runTestDB $ do
                uid <- insertTestUser now
                _ <- insert $ Post "첫번째" "내용1" uid now now
                _ <- insert $ Post "두번째" "내용2" uid now now
                posts <- selectList ([] :: [Filter Post]) [Desc PostCreatedAt]
                liftIO $ length posts `shouldBe` 2

        it "포스트를 수정할 수 있다" $ do
            now <- liftIO getCurrentTime
            runTestDB $ do
                uid <- insertTestUser now
                pid <- insert $ Post "원래제목" "원래본문" uid now now
                update pid [PostTitle =. "수정제목", PostContent =. "수정본문"]
                mPost <- get pid
                liftIO $ fmap postTitle mPost `shouldBe` Just "수정제목"
                liftIO $ fmap postContent mPost `shouldBe` Just "수정본문"

        it "포스트 삭제 시 관련 댓글도 함께 삭제된다" $ do
            now <- liftIO getCurrentTime
            runTestDB $ do
                uid <- insertTestUser now
                pid <- insert $ Post "삭제대상" "본문" uid now now
                _ <- insert $ Comment "댓글1" pid uid now
                _ <- insert $ Comment "댓글2" pid uid now
                commentsBefore <- selectList [CommentPostId ==. pid] []
                liftIO $ length commentsBefore `shouldBe` 2
                deleteWhere [CommentPostId ==. pid]
                delete pid
                mPost <- get pid
                liftIO $ mPost `shouldBe` (Nothing :: Maybe Post)
                commentsAfter <- selectList [CommentPostId ==. pid] []
                liftIO $ length commentsAfter `shouldBe` 0

        it "존재하지 않는 포스트 ID 조회 시 Nothing을 반환한다" $ do
            runTestDB $ do
                let nonExistentId = toSqlKey 99999 :: PostId
                mPost <- get nonExistentId
                liftIO $ mPost `shouldBe` (Nothing :: Maybe Post)
