-- | 애플리케이션 URL 경로의 단일 출처(single source of truth).
--
-- 같은 경로가 'Blog.App'(Scotty 라우트 정의)과 'Blog.View'(링크·폼 action),
-- 그리고 리다이렉트에 흩어져 stringly-typed 로 중복되던 것을 한 곳에 모은다.
--
-- 모든 값이 @IsString s => s@ 로 다형이라 호출 위치의 타입에 맞춰진다:
-- Scotty 의 @RoutePattern@, blaze 의 @AttributeValue@, 리다이렉트의 lazy @Text@
-- 어디서든 그대로 쓸 수 있다. 동적 경로는 'postPath' 같은 빌더로 만든다.
module Blog.Routes
  ( -- * 정적 경로 (라우트 정의·링크 공용)
    home
  , health
  , signup
  , login
  , logout
  , signupVerify
  , signupResend
  , profile
  , profilePassword
  , profileTheme
  , postsNew
  , postsCollection
  , postsPreview
  , postsDraft
  , previewFragment
    -- * 정적 자산 (브라우저 캐시 가능한 별도 라우트)
  , staticAppCss
  , staticAuthCss
  , staticThemeToggle
  , staticOrgEditor
    -- * 캡처 패턴 (Scotty 라우트 정의용)
  , userByIdPattern
  , postByIdPattern
  , postEditPattern
  , postPreviewPattern
  , postDraftPattern
  , postDeletePattern
    -- * 구체 경로 빌더 (링크·리다이렉트용)
  , userPath
  , postPath
  , postEditPath
  , postPreviewPath
  , postDraftPath
  , postDeletePath
  ) where

import Data.String (IsString, fromString)

-- 정적 경로 -------------------------------------------------------------

home, health, signup, login, logout, profile :: (IsString s) => s
home = "/"
health = "/health"
signup = "/signup"
login = "/login"
logout = "/logout"
profile = "/profile"

signupVerify, signupResend :: (IsString s) => s
signupVerify = "/signup/verify"
signupResend = "/signup/resend"

profilePassword, profileTheme :: (IsString s) => s
profilePassword = "/profile/password"
profileTheme = "/profile/theme"

postsNew, postsCollection, postsPreview, postsDraft, previewFragment :: (IsString s) => s
postsNew = "/posts/new"
postsCollection = "/posts"
postsPreview = "/posts/preview"
postsDraft = "/posts/draft"
previewFragment = "/preview-fragment"

-- 정적 자산 -------------------------------------------------------------
-- 컴파일 타임에 임베드한 CSS·JS 를 인라인하지 않고 별도 라우트로 서빙해
-- 브라우저·CDN 이 캐시하도록 한다(매 페이지 응답에서 자산 바이트를 덜어낸다).

staticAppCss, staticAuthCss, staticThemeToggle, staticOrgEditor :: (IsString s) => s
staticAppCss = "/static/app.css"
staticAuthCss = "/static/auth.css"
staticThemeToggle = "/static/theme-toggle.js"
staticOrgEditor = "/static/org-editor.js"

-- 캡처 패턴 (Scotty @:id@) -----------------------------------------------

userByIdPattern, postByIdPattern :: (IsString s) => s
userByIdPattern = "/users/:id"
postByIdPattern = "/posts/:id"

postEditPattern
  , postPreviewPattern
  , postDraftPattern
  , postDeletePattern
    :: (IsString s) => s
postEditPattern = "/posts/:id/edit"
postPreviewPattern = "/posts/:id/preview"
postDraftPattern = "/posts/:id/draft"
postDeletePattern = "/posts/:id/delete"

-- 구체 경로 빌더 --------------------------------------------------------

-- | 공개 프로필 경로 @\/users\/{id}@.
userPath :: (IsString s) => Int -> s
userPath uid = fromString ("/users/" <> show uid)

-- | 글 보기 경로 @\/posts\/{id}@.
postPath :: (IsString s) => Int -> s
postPath pid = fromString ("/posts/" <> show pid)

-- | 글 수정(발행) 경로 @\/posts\/{id}\/edit@.
postEditPath :: (IsString s) => Int -> s
postEditPath pid = fromString ("/posts/" <> show pid <> "/edit")

-- | 글 수정 미리보기 경로 @\/posts\/{id}\/preview@.
postPreviewPath :: (IsString s) => Int -> s
postPreviewPath pid = fromString ("/posts/" <> show pid <> "/preview")

-- | 수정 폼 되돌리기 경로 @\/posts\/{id}\/draft@.
postDraftPath :: (IsString s) => Int -> s
postDraftPath pid = fromString ("/posts/" <> show pid <> "/draft")

-- | 글 삭제 경로 @\/posts\/{id}\/delete@.
postDeletePath :: (IsString s) => Int -> s
postDeletePath pid = fromString ("/posts/" <> show pid <> "/delete")
