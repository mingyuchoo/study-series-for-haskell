-- | Scotty 애플리케이션 조립 — 영역별 라우트 모듈을 한데 모은다.
--
-- 실제 핸들러는 'Blog.App.AuthRoutes'/'Blog.App.PostRoutes'/'Blog.App.ProfileRoutes' 에 있고,
-- 공용 환경·헬퍼는 'Blog.App.Common' 에 있다. 이 모듈은 그것들을 등록만 한다.
module Blog.App
  ( application
  , Env (..)
  ) where

import Data.Text (Text)
import Data.Text.Lazy qualified as TL
import Data.Text.Lazy.Encoding qualified as TLE
import Network.Wai.Middleware.Gzip (defaultGzipSettings, gzip)
import Web.Scotty (ActionM, ScottyM, get, middleware, raw, setHeader, text)

import Blog.App.AuthRoutes (authRoutes)
import Blog.App.Common (Env (..))
import Blog.App.PostRoutes (postRoutes)
import Blog.App.ProfileRoutes (profileRoutes)
import Blog.Routes qualified as R
import Blog.View.Assets (authCss, orgEditorScript, pageCss, themeToggleScript)

-- | 주입된 환경으로 라우트 테이블을 구성한다.
--
-- 영역 간 경로가 겹치지 않으므로 등록 순서는 자유롭다. 단, 글 영역 안에서
-- @\/posts\/new@ 가 @\/posts\/:id@ 보다 먼저 와야 하며 그 순서는 'postRoutes'
-- 안에서 보장된다.
application :: Env -> ScottyM ()
application env = do
  -- 텍스트 응답(HTML·CSS·JS)을 gzip 압축한다(대량 트래픽에서 대역폭 대폭 절감).
  -- 기본 설정은 mime 타입·최소 크기 임계값을 보고 적절한 응답만 압축한다.
  middleware (gzip defaultGzipSettings)
  get R.health $ text "ok" -- ACA/로드밸런서 헬스 프로브용
  staticRoutes
  authRoutes env
  postRoutes env
  profileRoutes env

-- | 임베드된 CSS·JS 를 캐시 가능한 별도 라우트로 서빙한다(인라인 제거).
--   내용은 재배포 시에만 바뀌므로 1시간 캐시한다.
staticRoutes :: ScottyM ()
staticRoutes = do
  get R.staticAppCss $ serveAsset css pageCss
  get R.staticAuthCss $ serveAsset css authCss
  get R.staticThemeToggle $ serveAsset js themeToggleScript
  get R.staticOrgEditor $ serveAsset js orgEditorScript
  where
    css = "text/css; charset=utf-8"
    js = "text/javascript; charset=utf-8"

-- | 주어진 Content-Type 으로 텍스트 자산을 캐시 헤더와 함께 응답한다.
serveAsset :: TL.Text -> Text -> ActionM ()
serveAsset contentType body = do
  setHeader "Content-Type" contentType
  setHeader "Cache-Control" "public, max-age=3600"
  raw (TLE.encodeUtf8 (TL.fromStrict body))
