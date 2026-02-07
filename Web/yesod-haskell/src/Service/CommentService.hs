{-# LANGUAGE OverloadedStrings #-}

-- | [REQ-F004] 댓글 비즈니스 로직
module Service.CommentService where

import Import

-- | 특정 포스트의 댓글 조회 (최신순)
getCommentsByPostId :: PostId -> SqlPersistT (HandlerFor App) [Entity Comment]
getCommentsByPostId postId =
    selectList [CommentPostId ==. postId] [Desc CommentCreatedAt]

-- | 댓글 생성
createComment :: Text -> PostId -> UserId -> SqlPersistT (HandlerFor App) CommentId
createComment content postId authorId = do
    now <- liftIO getCurrentTime
    insert $ Comment content postId authorId now

-- | 댓글 삭제 (본인 또는 포스트 작성자만 가능)
deleteCommentIfAuthorized :: CommentId -> UserId -> SqlPersistT (HandlerFor App) Bool
deleteCommentIfAuthorized commentId currentUserId = do
    mComment <- get commentId
    case mComment of
        Nothing -> return False
        Just comment -> do
            mPost <- get (commentPostId comment)
            let isCommentAuthor = commentAuthorId comment == currentUserId
                isPostAuthor = maybe False (\p -> postAuthorId p == currentUserId) mPost
            if isCommentAuthor || isPostAuthor
                then do
                    delete commentId
                    return True
                else return False
