{-# LANGUAGE LambdaCase        #-}
{-# LANGUAGE OverloadedStrings #-}

module Event
    ( formatFileError
    , handleEvent
    , loadSelectedFile
    ) where
import           Brick
import           Brick.Widgets.List

import           Config                 (KeyBindingStyle (..))

import           Control.Exception      (IOException, catch)
import           Control.Monad.IO.Class (liftIO)

import qualified Data.Text              as T
import qualified Data.Text.IO           as TIO

import           Flow                   ((<|))

import           Fuzzy                  (filterItems)

import qualified Graphics.Vty           as V

import           System.IO.Error        (isDoesNotExistError, isPermissionError)

import           Types

-- | 메인 이벤트 핸들러 (Effect)
-- 키바인딩 스타일에 따라 Emacs 또는 Vim 핸들러로 분기
-- 터미널 리사이즈 이벤트는 키바인딩과 무관하게 처리
handleEvent :: BrickEvent Name e -> EventM Name AppState ()
handleEvent (VtyEvent e) = do
  st <- get
  case e of
    -- 터미널 리사이즈 처리
    V.EvResize w h -> modify $ \s -> s { stTerminalSize = (w, h) }
    -- 키 이벤트는 키바인딩 스타일에 따라 분기
    _ -> case configKeyBinding (stConfig st) of
           Emacs -> handleEmacsEvent e
           Vim   -> handleVimEvent e
handleEvent _ = pure ()

-- | 공통 키 이벤트 핸들러 (Effect)
-- 키바인딩 스타일과 무관한 공통 키 처리
-- 처리된 경우 True, 아닌 경우 False 반환
handleCommonEvent :: V.Event -> EventM Name AppState Bool
handleCommonEvent = \case
  V.EvKey V.KEsc []               -> halt >> pure True
  V.EvKey V.KEnter []             -> halt >> pure True
  V.EvKey V.KUp []                -> modify moveUp >> loadSelectedFile >> pure True
  V.EvKey V.KDown []              -> modify moveDown >> loadSelectedFile >> pure True
  V.EvKey (V.KChar 'u') [V.MCtrl] -> modify clearQuery >> loadSelectedFile >> pure True
  V.EvKey (V.KChar c) []          -> modify (appendChar c) >> loadSelectedFile >> pure True
  V.EvKey V.KBS []                -> modify deleteChar >> loadSelectedFile >> pure True
  _                               -> pure False

-- | Emacs 스타일 키 이벤트 핸들러 (Effect)
-- C-p/C-n으로 이동, C-g로 종료, C-h로 문자 삭제
handleEmacsEvent :: V.Event -> EventM Name AppState ()
handleEmacsEvent e = do
  handled <- handleCommonEvent e
  if handled then pure ()
  else case e of
    V.EvKey (V.KChar 'p') [V.MCtrl] -> modify moveUp >> loadSelectedFile
    V.EvKey (V.KChar 'n') [V.MCtrl] -> modify moveDown >> loadSelectedFile
    V.EvKey (V.KChar 'g') [V.MCtrl] -> halt
    V.EvKey (V.KChar 'h') [V.MCtrl] -> modify deleteChar >> loadSelectedFile
    _                               -> pure ()

-- | Vim 스타일 키 이벤트 핸들러 (Effect)
-- C-k/C-j로 이동, C-c로 종료, C-w로 문자 삭제
handleVimEvent :: V.Event -> EventM Name AppState ()
handleVimEvent e = do
  handled <- handleCommonEvent e
  if handled then pure ()
  else case e of
    V.EvKey (V.KChar 'k') [V.MCtrl] -> modify moveUp >> loadSelectedFile
    V.EvKey (V.KChar 'j') [V.MCtrl] -> modify moveDown >> loadSelectedFile
    V.EvKey (V.KChar 'c') [V.MCtrl] -> halt
    V.EvKey (V.KChar 'w') [V.MCtrl] -> modify deleteChar >> loadSelectedFile
    _                               -> pure ()

-- 상태 변경 함수들

-- | 검색어 업데이트 및 필터링 결과 갱신 (Pure)
-- 새 검색어로 아이템을 필터링하고 상태 업데이트
updateSearchQuery :: T.Text -> AppState -> AppState
updateSearchQuery newQuery st =
  let filtered = filterItems newQuery (stItems st)
      newList  = list ItemList filtered 1
  in st { stSearchQuery = newQuery, stFilteredList = newList }

-- | 검색어 끝에 문자 추가 (Pure)
-- 입력된 문자를 검색어에 추가하고 필터링 갱신
appendChar :: Char -> AppState -> AppState
appendChar c st = updateSearchQuery (stSearchQuery st `T.snoc` c) st

-- | 검색어 마지막 문자 삭제 (Pure)
-- 검색어가 비어있으면 변경 없음
deleteChar :: AppState -> AppState
deleteChar st
  | T.null (stSearchQuery st) = st
  | otherwise = updateSearchQuery (T.init <| stSearchQuery st) st

-- | 검색어 전체 삭제 (Pure)
-- 검색어를 빈 문자열로 초기화
clearQuery :: AppState -> AppState
clearQuery = updateSearchQuery ""

-- | 리스트에서 위로 이동 (Pure)
-- 선택 항목을 한 칸 위로 이동
moveUp :: AppState -> AppState
moveUp st = st { stFilteredList = listMoveUp (stFilteredList st) }

-- | 리스트에서 아래로 이동 (Pure)
-- 선택 항목을 한 칸 아래로 이동
moveDown :: AppState -> AppState
moveDown st = st { stFilteredList = listMoveDown (stFilteredList st) }

-- | 선택된 파일의 내용을 로드 (Effect)
-- 파일을 읽어서 상태에 저장, 에러 발생 시 에러 메시지 표시
loadSelectedFile :: EventM Name AppState ()
loadSelectedFile = do
  st <- get
  case listSelectedElement (stFilteredList st) of
    Nothing -> modify <| \s -> s { stFileContent = Nothing }
    Just (_, filePath) -> do
      content <- liftIO <| loadFileContent (T.unpack filePath)
      modify <| \s -> s { stFileContent = Just content }

-- | IOException을 사용자 친화적인 메시지로 변환 (Pure)
-- 파일 없음, 권한 없음, 기타 에러를 구분하여 한국어 메시지 반환
formatFileError :: IOException -> T.Text
formatFileError e
  | isDoesNotExistError e = "파일이 존재하지 않습니다"
  | isPermissionError e   = "파일 읽기 권한이 없습니다"
  | otherwise             = "파일 읽기 오류: " <> T.pack (show e)

-- | 파일 내용을 읽어오는 헬퍼 함수 (Effect)
-- 파일 읽기 실패 시 에러 메시지 반환
loadFileContent :: FilePath -> IO T.Text
loadFileContent path =
  (TIO.readFile path `catch` handleError)
  where
    handleError :: IOException -> IO T.Text
    handleError = return . formatFileError
