{-# LANGUAGE TemplateHaskell #-}

-- | 정적 자산(CSS·클라이언트 JS)을 컴파일 타임에 바이너리로 임베드한다.
--
-- 실제 내용은 프로젝트 루트의 @assets/@ 디렉터리에 있는 @.css@/@.js@ 파일이다.
-- 덕분에 에디터의 구문 강조·린팅·포매팅을 그대로 누리면서도, file-embed 로
-- 실행 파일 안에 박으므로 단일 바이너리 배포(Dockerfile)는 변하지 않는다.
-- UTF-8 글리프(@◉@ @✿@ @•@ @➤@)를 안전하게 다루기 위해 바이트로 읽어 'decodeUtf8'
-- 한다.
module Blog.View.Assets
  ( pageCss
  , authCss
  , themeInitScript
  , themeToggleScript
  , orgEditorScript
  ) where

import Data.FileEmbed (embedFile)
import Data.Text (Text)
import Data.Text.Encoding (decodeUtf8)

-- | 페이지 전역 스타일(라이트/다크 토큰 포함). @assets/app.css@.
pageCss :: Text
pageCss = decodeUtf8 $(embedFile "assets/app.css")

-- | 인증·프로필 UI 스타일. @assets/auth.css@.
authCss :: Text
authCss = decodeUtf8 $(embedFile "assets/auth.css")

-- | FOUC 방지용 테마 선적용 스크립트. @assets/theme-init.js@.
themeInitScript :: Text
themeInitScript = decodeUtf8 $(embedFile "assets/theme-init.js")

-- | 테마 토글 버튼 처리 스크립트. @assets/theme-toggle.js@.
themeToggleScript :: Text
themeToggleScript = decodeUtf8 $(embedFile "assets/theme-toggle.js")

-- | CodeMirror 기반 Org 라이브 에디터 스크립트(ESM). @assets/org-editor.js@.
orgEditorScript :: Text
orgEditorScript = decodeUtf8 $(embedFile "assets/org-editor.js")
