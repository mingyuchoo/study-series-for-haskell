-- | 프로필 라우트 — 본인 프로필·이름/소개 수정·비밀번호 변경·테마 저장·공개 프로필.
module Blog.App.ProfileRoutes
  ( profileRoutes
  ) where

import Control.Monad.IO.Class (liftIO)
import Data.Text (Text)
import Data.Text qualified as T
import Network.HTTP.Types.Status (badRequest400)
import Web.Scotty (ActionM, ScottyM, formParam, get, pathParam, post, redirect, status)

import Blog.App.Common
  ( Env (..)
  , currentViewer
  , notFoundView
  , renderView
  , viewerOf
  , withAuth
  )
import Blog.Auth (AuthUser, authedUser, hashPassword, verifyPassword)
import Blog.Post (PostStore (..))
import Blog.Routes qualified as R
import Blog.User (User (..), UserStore (..), parseTheme)
import Blog.View (renderProfile)

profileRoutes :: Env -> ScottyM ()
profileRoutes env = do
  -- 본인 프로필: 정보·소개 + 작성한 글 + 수정/비밀번호/테마 설정.
  get R.profile $ withAuth env $ \user ->
    ownProfileView env user Nothing

  -- 프로필 수정(표시 이름·소개). 이름은 비울 수 없다.
  post R.profile $ withAuth env $ \user -> do
    name <- formParam "name"
    bio <- formParam "bio"
    if T.null (T.strip name)
      then status badRequest400 >> ownProfileView env user (Just "표시 이름을 입력하세요.")
      else do
        _ <- liftIO (userUpdateProfile (envUsers env) (userId (authedUser user)) name bio)
        redirect R.profile

  -- 비밀번호 변경. 현재 비밀번호로 본인 확인 후 새 비밀번호로 바꾼다.
  post R.profilePassword $ withAuth env $ \user -> do
    let u = authedUser user
    current <- formParam "current"
    new <- formParam "new"
    confirm <- formParam "confirm"
    if not (verifyPassword current (userPasswordHash u))
      then status badRequest400 >> ownProfileView env user (Just "현재 비밀번호가 올바르지 않습니다.")
      else
        if T.length new < 8
          then status badRequest400 >> ownProfileView env user (Just "새 비밀번호는 8자 이상이어야 합니다.")
          else
            if new /= confirm
              then status badRequest400 >> ownProfileView env user (Just "새 비밀번호가 일치하지 않습니다.")
              else do
                hash <- liftIO (hashPassword new)
                _ <- liftIO (userUpdatePassword (envUsers env) (userId u) hash)
                redirect R.profile

  -- 계정 테마 저장. 프로필 폼과 헤더 토글(fetch)이 같은 경로를 쓴다.
  post R.profileTheme $ withAuth env $ \user -> do
    theme <- formParam "theme"
    _ <- liftIO (userUpdateTheme (envUsers env) (userId (authedUser user)) (parseTheme theme))
    redirect R.profile

  -- 공개 프로필: 해당 사용자의 정보·소개 + 작성한 글(수정 폼 없음).
  get R.userByIdPattern $ do
    viewer <- currentViewer env
    uid <- pathParam "id"
    mUser <- liftIO (userById (envUsers env) uid)
    case mUser of
      Just u -> do
        posts <- liftIO (storeListByAuthor (envPosts env) (userId u))
        renderView (renderProfile viewer u posts False Nothing)
      Nothing -> notFoundView viewer

-- | 본인 프로필 페이지를 렌더한다(작성한 글 + 선택적 알림 메시지).
--   프로필 조회와 각종 설정 변경 실패 재표시에 공통으로 쓴다.
ownProfileView :: Env -> AuthUser -> Maybe Text -> ActionM ()
ownProfileView env user mErr = do
  let u = authedUser user
  posts <- liftIO (storeListByAuthor (envPosts env) (userId u))
  renderView (renderProfile (viewerOf user) u posts True mErr)
