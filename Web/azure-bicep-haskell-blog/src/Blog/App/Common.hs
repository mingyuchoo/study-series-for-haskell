-- | 웹 계층 공용 부품 — 라우트 영역 모듈들이 공유하는 환경과 핸들러 헬퍼.
--
-- 'Blog.App.AuthRoutes'/'Blog.App.PostRoutes'/'Blog.App.ProfileRoutes' 가 모두 이 모듈에 의존하고,
-- 'Blog.App' 이 그 영역들을 조립한다. (영역 모듈이 서로를 import 하지 않게 하는
-- 공통 기반)
module Blog.App.Common
  ( -- * 런타임 환경
    Env (..)
    -- * 응답
  , renderView
  , notFoundView
  , forbiddenView
    -- * 인증 컨텍스트
  , currentViewer
  , viewerOf
  , withAuth
    -- * 세션
  , startSession
  , endSession
    -- * 코드 해시
  , hashCode
  ) where

import Control.Monad.IO.Class (liftIO)
import Data.ByteString.Lazy qualified as LBS
import Data.Text (Text)
import Data.Text.Encoding qualified as TE
import Data.Text.Lazy qualified as TL
import Data.Text.Lazy.Encoding qualified as TLE
import Data.Time.Clock (addUTCTime, getCurrentTime)
import Network.HTTP.Types.Status (forbidden403, notFound404)
import Text.Blaze.Html (Html)
import Text.Blaze.Html.Renderer.Text (renderHtml)
import Web.Cookie (parseCookies)
import Web.Scotty (ActionM, addHeader, header, html, redirect, status)

import Blog.Auth
  ( AuthUser
  , authedUser
  , hmacHex
  , makeSessionValue
  , renderClearSetCookie
  , renderSessionSetCookie
  , resolveSession
  , sessionCookieName
  , sessionTtlSeconds
  )
import Blog.Email (EmailSender)
import Blog.Keys (AppKeys (..))
import Blog.Post (PostStore)
import Blog.Routes qualified as R
import Blog.User (User (..), UserStore (..))
import Blog.Verification (VerificationStore)
import Blog.View (Viewer, ViewerInfo (..), renderForbidden, renderNotFound)

-- | 핸들러가 공유하는 런타임 의존성.
--
-- 'PostStore'/'UserStore'/'VerificationStore' 추상에만 의존하므로 구체 영속성
-- 구현(DB 등)은 알지 못한다. 'envKeys' 는 미리보기 토큰·세션 쿠키·인증 코드
-- 서명에 쓰는 용도별 분리 키다.
data Env = Env
  { envKeys   :: AppKeys
  , envUsers  :: UserStore
  , envPosts  :: PostStore
  , envSender :: EmailSender
  , envVerify :: VerificationStore
  }

-- | blaze 'Html'을 응답 본문으로 렌더링한다.
renderView :: Html -> ActionM ()
renderView = html . renderHtml

-- | 404 상태와 함께 \"찾을 수 없음\" 페이지를 렌더링한다.
notFoundView :: Viewer -> ActionM ()
notFoundView viewer = do
  status notFound404
  renderView (renderNotFound viewer)

-- | 403 상태와 함께 \"권한 없음\" 페이지를 렌더링한다.
forbiddenView :: Viewer -> ActionM ()
forbiddenView viewer = do
  status forbidden403
  renderView (renderForbidden viewer)

-- | 세션 쿠키에서 현재 사용자를 복원한다(없거나 무효면 'Nothing').
currentUser :: Env -> ActionM (Maybe AuthUser)
currentUser env = do
  mCookieHdr <- header "Cookie"
  case mCookieHdr >>= sessionValueFromHeader of
    Nothing -> pure Nothing
    Just val -> do
      now <- liftIO getCurrentTime
      liftIO (resolveSession (sessionKey (envKeys env)) now (userById (envUsers env)) val)

-- | 헤더 표시·소유권 판정용 현재 사용자(비로그인은 'Nothing').
currentViewer :: Env -> ActionM Viewer
currentViewer env = fmap (fmap viewerInfo) (currentUser env)

-- | 인증된 사용자를 'ViewerInfo' 로.
viewerInfo :: AuthUser -> ViewerInfo
viewerInfo au = ViewerInfo (userId u) (userName u) (userTheme u)
  where
    u = authedUser au

-- | 인증된 사용자를 'Viewer' 로.
viewerOf :: AuthUser -> Viewer
viewerOf = Just . viewerInfo

-- | 인증이 필요한 라우트 래퍼. 미로그인 시 로그인 페이지로 보낸다.
withAuth :: Env -> (AuthUser -> ActionM ()) -> ActionM ()
withAuth env act = do
  mUser <- currentUser env
  maybe (redirect R.login) act mUser

-- | "Cookie" 헤더 문자열에서 세션 쿠키 값을 뽑는다.
sessionValueFromHeader :: TL.Text -> Maybe Text
sessionValueFromHeader h =
  fmap TE.decodeUtf8 (lookup sessionCookieName cookies)
  where
    cookies = parseCookies (LBS.toStrict (TLE.encodeUtf8 h))

-- | 로그인 세션 쿠키를 설정한다.
startSession :: Env -> User -> ActionM ()
startSession env user = do
  now <- liftIO getCurrentTime
  let expiry = addUTCTime (fromIntegral sessionTtlSeconds) now
  addHeader
    "Set-Cookie"
    (renderSessionSetCookie (makeSessionValue (sessionKey (envKeys env)) (userId user) expiry))

-- | 세션 쿠키를 즉시 만료시킨다(로그아웃).
endSession :: ActionM ()
endSession = addHeader "Set-Cookie" renderClearSetCookie

-- | 인증 코드(평문)를 도메인 분리 키로 HMAC 해시한다(저장·비교 공용).
hashCode :: Env -> Text -> Text
hashCode env = hmacHex (verifyKey (envKeys env))
