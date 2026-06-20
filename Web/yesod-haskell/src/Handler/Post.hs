{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes       #-}
{-# LANGUAGE TemplateHaskell   #-}

-- | [REQ-F003] 포스트 CRUD 핸들러 (HTML)
module Handler.Post
  where

import Import
import Service.CommentService (getCommentsByPostId)
import Service.PostService

-- | 포스트 목록
getPostListR :: HandlerFor App Html
getPostListR = do
  posts <- runDB getAllPosts
  authors <- runDB $ mapM (\(Entity _ p) -> get (postAuthorId p)) posts
  let postsWithAuthors = zip posts authors
  defaultLayout $ do
    setTitle "포스트 목록"
    toWidget $(hamletFile "templates/post/list.hamlet")

-- | 포스트 작성 폼
getPostNewR :: HandlerFor App Html
getPostNewR = do
  _ <- requireAuthId
  let mPost = Nothing :: Maybe Post
  defaultLayout $ do
    setTitle "새 포스트 작성"
    toWidget $(hamletFile "templates/post/form.hamlet")

-- | 포스트 작성 처리
postPostNewR :: HandlerFor App Html
postPostNewR = do
  uid <- requireAuthId
  title <- runInputPost $ ireq textField "title"
  content <- runInputPost $ ireq textField "content"
  postId <- runDB $ createPost title content uid
  setMessage "포스트가 작성되었습니다."
  redirect (PostDetailR postId)

-- | 포스트 상세 조회
getPostDetailR :: PostId -> HandlerFor App Html
getPostDetailR postId = do
  mPost <- runDB $ getPostById postId
  case mPost of
    Nothing -> notFound
    Just post -> do
      author <- runDB $ get (postAuthorId post)
      comments <- runDB $ getCommentsByPostId postId
      commentAuthors <- runDB $ mapM (\(Entity _ c) -> get (commentAuthorId c)) comments
      let commentsWithAuthors = zip comments commentAuthors
      mCurrentUserId <- maybeAuthId
      defaultLayout $ do
        setTitle (toHtml $ postTitle post)
        toWidget $(hamletFile "templates/post/detail.hamlet")

-- | 포스트 수정 폼
getPostEditR :: PostId -> HandlerFor App Html
getPostEditR postId = do
  uid <- requireAuthId
  mResult <- runDB $ getPostById postId
  case mResult of
    Nothing -> notFound
    Just post -> do
      if postAuthorId post /= uid
        then permissionDenied "본인의 포스트만 수정할 수 있습니다."
        else do
          let mPost = Just post
          defaultLayout $ do
            setTitle "포스트 수정"
            toWidget $(hamletFile "templates/post/form.hamlet")

-- | 포스트 수정 처리
postPostEditR :: PostId -> HandlerFor App Html
postPostEditR postId = do
  uid <- requireAuthId
  mPost <- runDB $ getPostById postId
  case mPost of
    Nothing -> notFound
    Just post -> do
      if postAuthorId post /= uid
        then permissionDenied "본인의 포스트만 수정할 수 있습니다."
        else do
          title <- runInputPost $ ireq textField "title"
          content <- runInputPost $ ireq textField "content"
          runDB $ updatePost postId title content
          setMessage "포스트가 수정되었습니다."
          redirect (PostDetailR postId)

-- | 포스트 삭제 처리
postPostDeleteR :: PostId -> HandlerFor App Html
postPostDeleteR postId = do
  uid <- requireAuthId
  mPost <- runDB $ getPostById postId
  case mPost of
    Nothing -> notFound
    Just post -> do
      if postAuthorId post /= uid
        then permissionDenied "본인의 포스트만 삭제할 수 있습니다."
        else do
          runDB $ deletePostWithComments postId
          setMessage "포스트가 삭제되었습니다."
          redirect PostListR
