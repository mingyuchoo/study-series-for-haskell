{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}

-- | [REQ-F004] 댓글 JSON API 핸들러
module Handler.ApiComment
  where

import Data.Aeson (object, withObject, (.:), (.=))
import Data.Aeson qualified as Aeson
import Data.Aeson.Types (parseMaybe)
import Import
import Service.CommentService

-- | GET /api/posts/:postId/comments — 댓글 목록 조회
getApiCommentListR :: PostId -> HandlerFor App Aeson.Value
getApiCommentListR postId = do
  comments <- runDB $ getCommentsByPostId postId
  returnJson $ object ["comments" .= map commentEntityToJson comments]

-- | POST /api/posts/:postId/comments — 댓글 생성
postApiCommentListR :: PostId -> HandlerFor App Aeson.Value
postApiCommentListR postId = do
  uid <- requireAuthId
  body <- requireCheckJsonBody :: HandlerFor App Aeson.Value
  case parseCommentInput body of
    Nothing -> invalidArgs ["content가 필요합니다."]
    Just content -> do
      commentId <- runDB $ createComment content postId uid
      returnJson $ object ["id" .= commentId, "message" .= ("생성 완료" :: Text)]

-- | DELETE /api/comments/:commentId — 댓글 삭제
deleteApiCommentDeleteR :: CommentId -> HandlerFor App Aeson.Value
deleteApiCommentDeleteR commentId = do
  uid <- requireAuthId
  deleted <- runDB $ deleteCommentIfAuthorized commentId uid
  if deleted
    then returnJson $ object ["message" .= ("삭제 완료" :: Text)]
    else permissionDenied "댓글을 삭제할 권한이 없습니다."

-- 내부 헬퍼 함수

parseCommentInput :: Aeson.Value -> Maybe Text
parseCommentInput = parseMaybe $ withObject "comment" $ \o ->
  o .: "content"

commentEntityToJson :: Entity Comment -> Aeson.Value
commentEntityToJson (Entity cid Comment {..}) =
  object
    [ "id" .= cid
    , "content" .= commentContent
    , "postId" .= commentPostId
    , "authorId" .= commentAuthorId
    , "createdAt" .= commentCreatedAt
    ]
