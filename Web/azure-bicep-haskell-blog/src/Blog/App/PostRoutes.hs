{-# LANGUAGE DataKinds #-}

-- | 글 관련 라우트 — 목록·작성·미리보기·발행·수정·삭제·조회.
--   미리보기 토큰('Article')으로 "미리보기를 거친 글"만 발행되도록 타입 강제한다.
module Blog.App.PostRoutes
  ( postRoutes
  ) where

import Control.Monad.IO.Class (liftIO)
import Data.Text (Text)
import Network.HTTP.Types.Status (badRequest400)
import Web.Scotty
  ( ActionM
  , ScottyM
  , formParam
  , formParamMaybe
  , get
  , pathParam
  , post
  , redirect
  , status
  )

import Blog.App.Common
  ( Env (..)
  , currentViewer
  , forbiddenView
  , notFoundView
  , renderView
  , viewerOf
  , withAuth
  )
import Blog.Auth (AuthUser, authedUser)
import Blog.Keys (AppKeys (..))
import Blog.Org (renderOrgFragment)
import Blog.Post (NewPost (..), Post (..), PostStore (..), PostView (..))
import Blog.Publish
  ( Article
  , PostTarget (..)
  , Stage (..)
  , Token (..)
  , articleBody
  , articleTitle
  , mkDraft
  , signDraft
  , verifyPreviewed
  )
import Blog.Routes qualified as R
import Blog.User (User (..))
import Blog.View (renderEditForm, renderIndex, renderNewForm, renderPost, renderPreview)

postRoutes :: Env -> ScottyM ()
postRoutes env = do
  get R.home $ do
    viewer <- currentViewer env
    posts <- liftIO (storeList (envPosts env))
    renderView (renderIndex viewer posts)

  get R.postsNew $ withAuth env $ \user ->
    renderView (renderNewForm (viewerOf user) "" "")

  -- 라이브 에디터 미리보기용 본문 조각 렌더. 저장 없이 'renderOrgFragment'
  -- (발행과 동일한 렌더러) 결과만 HTML 조각으로 돌려준다.
  post R.previewFragment $ do
    body <- formParam "body"
    renderView (renderOrgFragment body)

  -- 새 글 발행 전 미리보기. 발행 단계에서 검증할 서명 토큰(대상: NewTarget)을
  -- 함께 발급한다.
  post R.postsPreview $ withAuth env $ \user -> do
    (title, body) <- formTitleBody
    previewResponse env user NewTarget title body

  -- 미리보기에서 "수정"을 누르면 입력값을 유지한 채 작성 폼으로 돌아간다.
  post R.postsDraft $ withAuth env $ \user -> do
    (title, body) <- formTitleBody
    renderView (renderNewForm (viewerOf user) title body)

  -- 새 글 발행. 유효한 토큰('Previewed')과 인증된 작성자('AuthUser')가 모두
  -- 있어야만 publishPost 를 호출할 수 있다(타입·토큰·세션 강제).
  post R.postsCollection $ withAuth env $ \user -> do
    (title, body) <- formTitleBody
    withPreviewed env user NewTarget title body $ \previewed -> do
      created <- liftIO (publishPost env user previewed)
      redirect (R.postPath (postId created))

  -- 아래 /posts/:id 수정·삭제 라우트는 모두 작성자 본인만 접근할 수 있다
  -- ('withOwnedPost' 가 404/403 을 처리).

  get R.postEditPattern $ withAuth env $ \user -> do
    pid <- pathParam "id"
    withOwnedPost env user pid $ \p ->
      renderView (renderEditForm (viewerOf user) (postId p) (postTitle p) (postBody p))

  -- 수정 발행 전 미리보기. 대상(EditTarget id)에 묶인 서명 토큰을 발급한다.
  post R.postPreviewPattern $ withAuth env $ \user -> do
    pid <- pathParam "id"
    withOwnedPost env user pid $ \_p -> do
      (title, body) <- formTitleBody
      previewResponse env user (EditTarget pid) title body

  -- 수정 미리보기에서 "수정"을 누르면 입력값을 유지한 채 수정 폼으로 돌아간다.
  post R.postDraftPattern $ withAuth env $ \user -> do
    pid <- pathParam "id"
    withOwnedPost env user pid $ \_p -> do
      (title, body) <- formTitleBody
      renderView (renderEditForm (viewerOf user) pid title body)

  -- 수정 발행(update). 토큰·세션·소유권을 모두 강제한다.
  post R.postEditPattern $ withAuth env $ \user -> do
    pid <- pathParam "id"
    withOwnedPost env user pid $ \_p -> do
      (title, body) <- formTitleBody
      withPreviewed env user (EditTarget pid) title body $ \previewed -> do
        mPost <- liftIO (publishUpdate env pid previewed)
        maybe (notFoundView (viewerOf user)) (const (redirect (R.postPath pid))) mPost

  post R.postDeletePattern $ withAuth env $ \user -> do
    pid <- pathParam "id"
    withOwnedPost env user pid $ \_p -> do
      _ <- liftIO (storeDelete (envPosts env) pid)
      redirect R.home

  get R.postByIdPattern $ do
    viewer <- currentViewer env
    pid <- pathParam "id"
    mPost <- liftIO (storeGet (envPosts env) pid)
    case mPost of
      Just p  -> renderView (renderPost viewer p)
      Nothing -> notFoundView viewer

-- | 글이 존재하고 현재 사용자가 그 작성자일 때만 act 를 실행한다.
--   없으면 404, 작성자가 아니면 403. act 에는 순수 저장 행('Post')을 넘긴다.
withOwnedPost :: Env -> AuthUser -> Int -> (Post -> ActionM ()) -> ActionM ()
withOwnedPost env user pid act = do
  mPost <- liftIO (storeGet (envPosts env) pid)
  case mPost of
    Nothing -> notFoundView (viewerOf user)
    Just pv
      | postAuthorId p == userId (authedUser user) -> act p
      | otherwise -> forbiddenView (viewerOf user)
      where
        p = pvPost pv

-- | 작성/수정 폼의 제목·본문 필드를 함께 읽는다.
formTitleBody :: ActionM (Text, Text)
formTitleBody = (,) <$> formParam "title" <*> formParam "body"

-- | 입력값을 미리보기 페이지로 렌더한다(대상에 묶인 서명 토큰을 새로 발급).
--   발행/수정 미리보기 진입과, 토큰 검증 실패 시 미리보기 재표시에 공통으로 쓴다.
previewResponse :: Env -> AuthUser -> PostTarget -> Text -> Text -> ActionM ()
previewResponse env user target title body =
  renderView
    ( renderPreview
        (viewerOf user)
        target
        title
        body
        (signDraft (tokenKey (envKeys env)) target (mkDraft title body))
    )

-- | 폼의 토큰을 검증해 미리보기를 거친 글일 때만 act 를 실행한다.
--   토큰이 없거나 (대상+내용)과 어긋나면 400과 함께 미리보기를 다시 보여준다.
withPreviewed
  :: Env
  -> AuthUser
  -> PostTarget
  -> Text
  -> Text
  -> (Article 'Previewed -> ActionM ())
  -> ActionM ()
withPreviewed env user target title body act = do
  mTok <- formParamMaybe "token"
  case mTok >>= \t -> verifyPreviewed (tokenKey (envKeys env)) target title body (Token t) of
    Just previewed -> act previewed
    Nothing        -> status badRequest400 >> previewResponse env user target title body

-- | 미리보기를 거친 글만, 인증된 작성자가 있을 때만 영속화한다.
publishPost :: Env -> AuthUser -> Article 'Previewed -> IO Post
publishPost env author a =
  storeInsert
    (envPosts env)
    (userId (authedUser author))
    (NewPost (articleTitle a) (articleBody a))

-- | 미리보기를 거친 글만 기존 글에 덮어쓴다(작성자는 유지).
publishUpdate :: Env -> Int -> Article 'Previewed -> IO (Maybe Post)
publishUpdate env pid a = storeUpdate (envPosts env) pid (NewPost (articleTitle a) (articleBody a))
