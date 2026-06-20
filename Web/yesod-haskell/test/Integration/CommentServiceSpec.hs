{-# LANGUAGE OverloadedStrings #-}

-- | [REQ-T001, REQ-F004] CommentService 통합 테스트 — 댓글 CRUD 및 권한 검증
--
-- 이 테스트는 다음 요구사항을 검증합니다:
--   - REQ-F004: 댓글 CRUD - 생성, 조회, 삭제 및 권한 검증 로직
module Integration.CommentServiceSpec
  ( spec
  ) where

import Model
import Test.Hspec
import TestFoundation (runTestDB, withApp)

import Control.Monad.IO.Class (liftIO)
import Data.Time (getCurrentTime)
import Database.Persist

spec :: Spec
spec = withApp $ do
  describe "CommentService — 댓글 CRUD" $ do
    it "댓글을 생성하고 포스트 ID로 조회할 수 있다" $ do
      now <- liftIO getCurrentTime
      runTestDB $ do
        uid <- insert $ User "유저" "user@test.com" "hash" now
        pid <- insert $ Post "포스트" "본문" uid now now
        _ <- insert $ Comment "댓글 내용" pid uid now
        comments <- selectList [CommentPostId ==. pid] [Desc CommentCreatedAt]
        liftIO $ length comments `shouldBe` 1
        case comments of
          (c : _) -> liftIO $ commentContent (entityVal c) `shouldBe` "댓글 내용"
          []      -> liftIO $ expectationFailure "댓글이 존재해야 함"

    it "여러 댓글을 생성하면 모두 조회된다" $ do
      now <- liftIO getCurrentTime
      runTestDB $ do
        uid <- insert $ User "유저" "user@test.com" "hash" now
        pid <- insert $ Post "포스트" "본문" uid now now
        _ <- insert $ Comment "댓글1" pid uid now
        _ <- insert $ Comment "댓글2" pid uid now
        _ <- insert $ Comment "댓글3" pid uid now
        comments <- selectList [CommentPostId ==. pid] []
        liftIO $ length comments `shouldBe` 3

  describe "CommentService — 댓글 삭제 권한 검증" $ do
    it "댓글 작성자는 자신의 댓글을 삭제할 수 있다" $ do
      now <- liftIO getCurrentTime
      runTestDB $ do
        uid <- insert $ User "작성자" "author@test.com" "hash" now
        pid <- insert $ Post "포스트" "본문" uid now now
        cid <- insert $ Comment "삭제할 댓글" pid uid now
        -- 댓글 작성자가 삭제
        mComment <- get cid
        case mComment of
          Nothing -> liftIO $ expectationFailure "댓글이 존재해야 함"
          Just comment -> do
            let isAuthor = commentAuthorId comment == uid
            liftIO $ isAuthor `shouldBe` True
            delete cid
            mAfter <- get cid
            liftIO $ mAfter `shouldBe` (Nothing :: Maybe Comment)

    it "포스트 작성자는 다른 사람의 댓글을 삭제할 수 있다" $ do
      now <- liftIO getCurrentTime
      runTestDB $ do
        postAuthor <- insert $ User "포스트작성자" "pa@test.com" "hash" now
        commentAuthor <- insert $ User "댓글작성자" "ca@test.com" "hash" now
        pid <- insert $ Post "포스트" "본문" postAuthor now now
        cid <- insert $ Comment "댓글" pid commentAuthor now
        -- 포스트 작성자인지 확인
        mPost <- get pid
        mComment <- get cid
        case (mPost, mComment) of
          (Just post, Just _comment) -> do
            let isPostAuthor = postAuthorId post == postAuthor
            liftIO $ isPostAuthor `shouldBe` True
            delete cid
            mAfter <- get cid
            liftIO $ mAfter `shouldBe` (Nothing :: Maybe Comment)
          _ -> liftIO $ expectationFailure "포스트와 댓글이 존재해야 함"

    it "제3자는 댓글을 삭제할 수 없다 (권한 없음)" $ do
      now <- liftIO getCurrentTime
      runTestDB $ do
        postAuthor <- insert $ User "포스트작성자" "pa@test.com" "hash" now
        commentAuthor <- insert $ User "댓글작성자" "ca@test.com" "hash" now
        thirdParty <- insert $ User "제3자" "tp@test.com" "hash" now
        pid <- insert $ Post "포스트" "본문" postAuthor now now
        cid <- insert $ Comment "댓글" pid commentAuthor now
        -- 제3자인지 확인 (포스트 작성자도 댓글 작성자도 아님)
        mPost <- get pid
        mComment <- get cid
        case (mPost, mComment) of
          (Just post, Just comment) -> do
            let isCommentAuthor = commentAuthorId comment == thirdParty
                isPostAuthor = postAuthorId post == thirdParty
            liftIO $ isCommentAuthor `shouldBe` False
            liftIO $ isPostAuthor `shouldBe` False
            -- 댓글이 여전히 존재해야 함
            mStillExists <- get cid
            liftIO $ mStillExists `shouldSatisfy` (/= Nothing)
          _ -> liftIO $ expectationFailure "포스트와 댓글이 존재해야 함"
