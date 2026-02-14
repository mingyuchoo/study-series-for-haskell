{-# LANGUAGE GeneralizedNewtypeDeriving #-}

module Types
    ( AppConfig (..)
    , AppState (..)
    , Name (..)
    , configWithKeyBinding
    , defaultConfig
    , initialState
    -- 터미널 크기 및 레이아웃 헬퍼 함수
    , isTerminalSizeSufficient
    , resultListWidth
    , previewWidth
    , contentHeight
    ) where
import           Brick              (on)
import           Brick.Widgets.List (List, list)

import           Config             (KeyBindingConfig (..),
                                     KeyBindingStyle (..))

import qualified Data.Text          as T
import qualified Data.Vector        as Vec

import qualified Graphics.Vty       as V

-- | 위젯 식별을 위한 이름 타입
-- Brick 위젯에서 포커스 및 이벤트 처리에 사용
data Name = ItemList
     deriving (Eq, Ord, Show)

-- | 앱 설정을 담는 불변 레코드 타입
-- UI 스타일 및 키바인딩 설정 포함
data AppConfig = AppConfig { configMaxWidth     :: !Int
                             -- ^ 최대 너비
                           , configDefaultAttr  :: !V.Attr
                             -- ^ 기본 속성
                           , configSelectedAttr :: !V.Attr
                             -- ^ 선택 항목 속성
                           , configKeyBinding   :: !KeyBindingStyle
                             -- ^ 키바인딩 스타일
                           }

-- | 앱의 현재 상태를 담는 레코드 타입
-- 아이템 목록, 필터링 결과, 검색어, 설정 포함
data AppState = AppState { stItems        :: !(Vec.Vector T.Text)
                           -- ^ 전체 아이템
                         , stFilteredList :: !(List Name T.Text)
                           -- ^ 필터링된 리스트
                         , stSearchQuery  :: !T.Text
                           -- ^ 현재 검색어
                         , stConfig       :: !AppConfig
                           -- ^ 앱 설정
                         , stFileContent  :: !(Maybe T.Text)
                           -- ^ 선택된 파일의 내용
                         }

-- | 기본 앱 설정값 (Pure)
-- 너비 80, 기본 속성, 파란 배경 선택 속성, Emacs 키바인딩
defaultConfig :: AppConfig
defaultConfig = AppConfig
  { configMaxWidth     = 80
  , configDefaultAttr  = V.defAttr
  , configSelectedAttr = V.white `on` V.blue
  , configKeyBinding   = Emacs
  }

-- | KeyBindingConfig로부터 AppConfig 생성 (Pure)
-- 키바인딩 설정만 적용하고 나머지는 기본값 사용
configWithKeyBinding :: KeyBindingConfig -> AppConfig
configWithKeyBinding kbConfig = defaultConfig
  { configKeyBinding = bindingStyle kbConfig
  }

-- | 아이템 목록과 설정으로 초기 상태 생성 (Pure)
-- 검색어는 빈 문자열로 초기화
initialState :: [T.Text] -> AppConfig -> AppState
initialState items cfg =
  let itemVec = Vec.fromList items
  in AppState
       { stItems        = itemVec
       , stFilteredList = list ItemList itemVec 1
       , stSearchQuery  = ""
       , stConfig       = cfg
       , stFileContent  = Nothing
       }

-- | 터미널이 최소 크기 이상인지 확인 (Pure)
-- 최소 크기: 80x24
isTerminalSizeSufficient :: (Int, Int) -> Bool
isTerminalSizeSufficient (w, h) = w >= 80 && h >= 24

-- | 결과 리스트 너비 계산 (Pure)
-- 전체 너비의 40%
resultListWidth :: Int -> Int
resultListWidth termWidth = (termWidth * 2) `div` 5

-- | 미리보기 너비 계산 (Pure)
-- 전체 너비의 60% (= 전체 - 40%)
previewWidth :: Int -> Int
previewWidth termWidth = termWidth - resultListWidth termWidth

-- | 컨텐츠 영역 높이 계산 (Pure)
-- 전체 높이 - 고정 요소들(검색 3줄 + 정보 3줄 + 도움말 2줄)
contentHeight :: Int -> Int
contentHeight termHeight = termHeight - 3 - 3 - 2
