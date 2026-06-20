{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}

-- | [REQ-F003] 포스트 JSON API 핸들러
module Handler.ApiPost
  where

import Data.Aeson (object, withObject, (.:), (.=))
import Data.Aeson qualified as Aeson
import Data.Aeson.Types (parseMaybe)
import Import
import Service.PostService

-- | GET /api/posts — 포스트 목록 조회
getApiPostListR :: HandlerFor App Aeson.Value
getApiPostListR = do
  posts <- runDB getAllPosts
  returnJson $ object ["posts" .= map entityToJson posts]

-- | POST /api/posts — 포스트 생성
postApiPostListR :: HandlerFor App Aeson.Value
postApiPostListR = do
  uid <- requireAuthId
  body <- requireCheckJsonBody :: HandlerFor App Aeson.Value
  case parsePostInput body of
    Nothing -> invalidArgs ["title과 content가 필요합니다."]
    Just (title, content) -> do
      postId <- runDB $ createPost title content uid
      returnJson $ object ["id" .= postId, "message" .= ("생성 완료" :: Text)]

-- | GET /api/posts/:id — 포스트 상세 조회
getApiPostDetailR :: PostId -> HandlerFor App Aeson.Value
getApiPostDetailR postId = do
  mPost <- runDB $ getPostById postId
  case mPost of
    Nothing   -> notFound
    Just post -> returnJson $ postToJson postId post

-- | PUT /api/posts/:id — 포스트 수정
putApiPostDetailR :: PostId -> HandlerFor App Aeson.Value
putApiPostDetailR postId = do
  uid <- requireAuthId
  mPost <- runDB $ getPostById postId
  case mPost of
    Nothing -> notFound
    Just post -> do
      if postAuthorId post /= uid
        then permissionDenied "본인의 포스트만 수정할 수 있습니다."
        else do
          body <- requireCheckJsonBody :: HandlerFor App Aeson.Value
          case parsePostInput body of
            Nothing -> invalidArgs ["title과 content가 필요합니다."]
            Just (title, content) -> do
              runDB $ updatePost postId title content
              returnJson $ object ["message" .= ("수정 완료" :: Text)]

-- | DELETE /api/posts/:id — 포스트 삭제
deleteApiPostDetailR :: PostId -> HandlerFor App Aeson.Value
deleteApiPostDetailR postId = do
  uid <- requireAuthId
  mPost <- runDB $ getPostById postId
  case mPost of
    Nothing -> notFound
    Just post -> do
      if postAuthorId post /= uid
        then permissionDenied "본인의 포스트만 삭제할 수 있습니다."
        else do
          runDB $ deletePostWithComments postId
          returnJson $ object ["message" .= ("삭제 완료" :: Text)]

-- 내부 헬퍼 함수

parsePostInput :: Aeson.Value -> Maybe (Text, Text)
parsePostInput = parseMaybe $ withObject "post" $ \o -> do
  title <- o .: "title"
  content <- o .: "content"
  return (title, content)

entityToJson :: Entity Post -> Aeson.Value
entityToJson (Entity pid post) = postToJson pid post

postToJson :: PostId -> Post -> Aeson.Value
postToJson pid Post {..} =
  object
    [ "id" .= pid
    , "title" .= postTitle
    , "content" .= postContent
    , "authorId" .= postAuthorId
    , "createdAt" .= postCreatedAt
    , "updatedAt" .= postUpdatedAt
    ]
