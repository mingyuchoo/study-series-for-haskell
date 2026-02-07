{-# LANGUAGE OverloadedStrings #-}

-- | [REQ-F004] 댓글 핸들러 (HTML)
module Handler.Comment where

import Import
import Service.CommentService

-- | POST /posts/:postId/comments — 댓글 작성
postCommentCreateR :: PostId -> HandlerFor App Html
postCommentCreateR postId = do
    uid     <- requireAuthId
    content <- runInputPost $ ireq textField "content"
    _       <- runDB $ createComment content postId uid
    setMessage "댓글이 작성되었습니다."
    redirect (PostDetailR postId)

-- | POST /comments/:commentId/delete — 댓글 삭제
postCommentDeleteR :: CommentId -> HandlerFor App Html
postCommentDeleteR commentId = do
    uid <- requireAuthId
    mComment <- runDB $ get commentId
    case mComment of
        Nothing -> notFound
        Just comment -> do
            deleted <- runDB $ deleteCommentIfAuthorized commentId uid
            if deleted
                then setMessage "댓글이 삭제되었습니다."
                else permissionDenied "댓글을 삭제할 권한이 없습니다."
            redirect (PostDetailR (commentPostId comment))
