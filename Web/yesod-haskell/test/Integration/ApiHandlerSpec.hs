{-# LANGUAGE OverloadedStrings #-}

-- | [REQ-T001, REQ-F002, REQ-F003, REQ-F004] API Handler 통합 테스트 — HTTP 수준 엔드포인트 검증
--
-- 이 테스트는 다음 요구사항을 검증합니다:
--   - REQ-F002: 사용자 인증 - 회원가입/로그인 페이지 렌더링
--   - REQ-F003: 포스트 CRUD - API 엔드포인트 응답 검증
--   - REQ-F004: 댓글 CRUD - API 엔드포인트 응답 검증
module Integration.ApiHandlerSpec (spec) where

import TestFoundation (makeTestFoundation)
import Foundation
import Model

import Test.Hspec
import Yesod.Test
import Yesod.Core (toPathPiece)

import Control.Monad.IO.Class (liftIO)
import Data.Aeson (object, (.=))
import qualified Data.Aeson as Aeson
import Data.Time (getCurrentTime)
import Database.Persist hiding (get)
import Database.Persist.Sql (SqlPersistT, runSqlPool, toSqlKey)

-- | 테스트 내에서 DB 작업을 수행하는 헬퍼
runDB :: SqlPersistT IO a -> YesodExample App a
runDB action = do
    app <- getTestYesod
    liftIO $ runSqlPool action (appConnectionPool app)

-- | 테스트용 사용자를 생성하고 세션 쿠키를 설정하는 헬퍼
authenticateUser :: YesodExample App UserId
authenticateUser = do
    now <- liftIO getCurrentTime
    uid <- runDB $ insert $ User "테스트유저" "test@test.com" "hash" now
    -- 세션 설정을 위해 로그인 시뮬레이션은 불가하므로,
    -- 직접 쿠키 기반으로 테스트할 수 없음.
    -- 대신 DB에 사용자를 만들고 ID를 반환
    return uid

spec :: Spec
spec = yesodSpecWithSiteGenerator makeTestFoundation $ do

    ydescribe "GET /api/posts" $ do

        yit "빈 목록을 반환한다" $ do
            get ApiPostListR
            statusIs 200
            bodyContains "\"posts\":[]"

        yit "포스트가 있으면 목록에 포함된다" $ do
            now <- liftIO getCurrentTime
            uid <- runDB $ insert $ User "유저" "u@test.com" "hash" now
            _ <- runDB $ insert $ Post "테스트 포스트" "본문 내용" uid now now
            get ApiPostListR
            statusIs 200
            bodyContains "테스트 포스트"

    ydescribe "GET /api/posts/:id" $ do

        yit "존재하는 포스트를 조회한다" $ do
            now <- liftIO getCurrentTime
            uid <- runDB $ insert $ User "유저" "u@test.com" "hash" now
            pid <- runDB $ insert $ Post "상세조회" "본문" uid now now
            get (ApiPostDetailR pid)
            statusIs 200
            bodyContains "상세조회"

        yit "존재하지 않는 포스트는 404를 반환한다" $ do
            get (ApiPostDetailR (toSqlKey 99999))
            statusIs 404

    ydescribe "POST /api/posts" $ do

        yit "미인증 시 리다이렉트한다" $ do
            request $ do
                setMethod "POST"
                setUrl ApiPostListR
                addRequestHeader ("Content-Type", "application/json")
                setRequestBody $ Aeson.encode $ object
                    [ "title" .= ("제목" :: String)
                    , "content" .= ("본문" :: String)
                    ]
            statusIs 303

    ydescribe "GET /api/posts/:postId/comments" $ do

        yit "빈 댓글 목록을 반환한다" $ do
            now <- liftIO getCurrentTime
            uid <- runDB $ insert $ User "유저" "u@test.com" "hash" now
            pid <- runDB $ insert $ Post "포스트" "본문" uid now now
            get (ApiCommentListR pid)
            statusIs 200
            bodyContains "\"comments\":[]"

        yit "댓글이 있으면 목록에 포함된다" $ do
            now <- liftIO getCurrentTime
            uid <- runDB $ insert $ User "유저" "u@test.com" "hash" now
            pid <- runDB $ insert $ Post "포스트" "본문" uid now now
            _ <- runDB $ insert $ Comment "테스트 댓글" pid uid now
            get (ApiCommentListR pid)
            statusIs 200
            bodyContains "테스트 댓글"

    ydescribe "GET / (홈)" $ do

        yit "홈 페이지가 200을 반환한다" $ do
            get HomeR
            statusIs 200

    ydescribe "GET /posts (포스트 목록)" $ do

        yit "포스트 목록 페이지가 200을 반환한다" $ do
            get PostListR
            statusIs 200

    ydescribe "GET /auth/register (회원가입)" $ do

        yit "회원가입 페이지가 200을 반환한다" $ do
            get RegisterR
            statusIs 200

    ydescribe "GET /auth/login (로그인)" $ do

        yit "로그인 페이지가 200을 반환한다" $ do
            get LoginR
            statusIs 200
