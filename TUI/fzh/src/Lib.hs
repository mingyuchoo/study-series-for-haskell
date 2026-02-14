module Lib
    ( -- * Re-exports
      module Config
    , module Types
      -- * App
    , app
    , buildVtyFromTty
    ) where
import           Brick
import           Brick.Widgets.List      (listSelectedAttr)

import           Config                  (KeyBindingConfig (..),
                                          KeyBindingStyle (..),
                                          defaultKeyBindingConfig,
                                          loadKeyBindingConfig)

import           Event                   (handleEvent, loadSelectedFile)

import qualified Graphics.Vty.Attributes as V

import           Types

import           UI                      (drawUI)

import           Vty                     (buildVtyFromTty)

-- | Brick 앱 정의 (Pure)
-- 드로잉, 커서, 이벤트 핸들링, 시작 이벤트, 속성 맵 설정
app :: App AppState e Name
app = App
  { appDraw         = drawUI
  , appChooseCursor = neverShowCursor
  , appHandleEvent  = handleEvent
  , appStartEvent   = loadSelectedFile
  , appAttrMap      = mkAttrMap
  }

-- | 앱 상태에서 속성 맵 생성 (Pure)
-- 기본 속성과 선택 항목 속성을 설정에서 가져옴
mkAttrMap :: AppState -> AttrMap
mkAttrMap st = attrMap (configDefaultAttr cfg)
  [ (listSelectedAttr, configSelectedAttr cfg)
  -- 구문 강조 색상
  , (attrName "syntax.keyword", fg V.brightBlue)
  , (attrName "syntax.string", fg V.yellow)
  , (attrName "syntax.comment", fg V.brightBlack)
  , (attrName "syntax.function", fg V.brightGreen)
  , (attrName "syntax.type", fg V.brightCyan)
  , (attrName "syntax.number", fg V.cyan)
  , (attrName "syntax.lineNumber", fg V.brightBlack)
  ]
  where
    cfg = stConfig st
