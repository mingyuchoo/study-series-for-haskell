-- | Scotty 애플리케이션 조립 — 영역별 라우트 모듈을 한데 모은다.
--
-- 실제 핸들러는 'Blog.App.AuthRoutes'/'Blog.App.PostRoutes'/'Blog.App.ProfileRoutes' 에 있고,
-- 공용 환경·헬퍼는 'Blog.App.Common' 에 있다. 이 모듈은 그것들을 등록만 한다.
module Blog.App
  ( application
  , Env (..)
  ) where

import Web.Scotty (ScottyM, get, text)

import Blog.App.AuthRoutes (authRoutes)
import Blog.App.Common (Env (..))
import Blog.App.PostRoutes (postRoutes)
import Blog.App.ProfileRoutes (profileRoutes)
import Blog.Routes qualified as R

-- | 주입된 환경으로 라우트 테이블을 구성한다.
--
-- 영역 간 경로가 겹치지 않으므로 등록 순서는 자유롭다. 단, 글 영역 안에서
-- @\/posts\/new@ 가 @\/posts\/:id@ 보다 먼저 와야 하며 그 순서는 'postRoutes'
-- 안에서 보장된다.
application :: Env -> ScottyM ()
application env = do
  get R.health $ text "ok" -- ACA/로드밸런서 헬스 프로브용
  authRoutes env
  postRoutes env
  profileRoutes env
