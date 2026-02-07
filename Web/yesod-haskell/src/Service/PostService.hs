{-# LANGUAGE OverloadedStrings #-}

-- | [REQ-F003] 포스트 비즈니스 로직
module Service.PostService where

import Import

-- | 최신순으로 모든 포스트 조회
getAllPosts :: SqlPersistT (HandlerFor App) [Entity Post]
getAllPosts = selectList [] [Desc PostCreatedAt]

-- | 포스트 ID로 조회
getPostById :: PostId -> SqlPersistT (HandlerFor App) (Maybe Post)
getPostById = get

-- | 새 포스트 생성
createPost :: Text -> Text -> UserId -> SqlPersistT (HandlerFor App) PostId
createPost title content authorId = do
    now <- liftIO getCurrentTime
    insert $ Post title content authorId now now

-- | 포스트 수정
updatePost :: PostId -> Text -> Text -> SqlPersistT (HandlerFor App) ()
updatePost postId title content = do
    now <- liftIO getCurrentTime
    update postId
        [ PostTitle   =. title
        , PostContent =. content
        , PostUpdatedAt =. now
        ]

-- | 포스트 삭제 (관련 댓글도 함께 삭제)
deletePostWithComments :: PostId -> SqlPersistT (HandlerFor App) ()
deletePostWithComments postId = do
    deleteWhere [CommentPostId ==. postId]
    delete postId
