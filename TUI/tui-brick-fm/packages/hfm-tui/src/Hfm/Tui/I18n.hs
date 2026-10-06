{-# LANGUAGE OverloadedStrings #-}

module Hfm.Tui.I18n (translate) where

import qualified Data.Text as T

import Hfm.Domain.Language (Language (..))

-- Translate application text only; paths, filenames and file contents stay intact.
translate :: Language -> T.Text -> T.Text
translate Korean value = value
translate English value = case lookup value translations of
  Just translated -> translated
  Nothing -> case T.stripPrefix "오류: " value of
    Just detail -> "Error: " <> translate English detail
    Nothing -> case T.stripPrefix "user error (" value >>= T.stripSuffix ")" of
      Just detail -> "user error (" <> translate English detail <> ")"
      Nothing -> value

translations :: [(T.Text, T.Text)]
translations =
  [ ("hfm  |  파일 관리자", "hfm  |  File manager")
  , ("C-x: C-c 종료  o 패널  C-f 열기  k 닫기  C-g 취소", "C-x: C-c Quit  o Panel  C-f Open  k Close  C-g Cancel")
  , ("C-x: C-c 종료  k 닫기  C-g 명령 취소", "C-x: C-c Quit  k Close  C-g Cancel command")
  , ("C-s/r 다음/이전  C-p/n 이동  C-v/M-v 페이지  C-g 취소", "C-s/r Next/Prev  C-p/n Move  C-v/M-v Page  C-g Cancel")
  , ("C-a/e 처음/끝  C-b/f 문자  M-b/f 단어  C-k/M-d 삭제", "C-a/e Start/End  C-b/f Char  M-b/f Word  C-k/M-d Delete")
  , ("y 삭제  n/C-g 취소", "y Delete  n/C-g Cancel")
  , ("C-p/n 이동  C-v/M-v 페이지  M-</> 처음/끝  C-x o 패널  C-x C-c 종료", "C-p/n Move  C-v/M-v Page  M-</> Start/End  C-x o Panel  C-x C-c Quit")
  , ("C-s/r 검색  RET 열기  ^ 상위  v 보기  C 복사  R 이동  + 폴더  D 삭제  M-o 숨김  g 갱신", "C-s/r Search  RET Open  ^ Parent  v View  C Copy  R Move  + Folder  D Delete  M-o Hidden  g Refresh")
  , ("검색: ", "Search: ")
  , ("  (RET 적용, C-g 취소)", "  (RET Apply, C-g Cancel)")
  , ("복사 대상: ", "Copy to: ")
  , ("이동/새 이름: ", "Move/rename to: ")
  , ("새 폴더: ", "New folder: ")
  , ("  (RET 실행, C-g 취소)", "  (RET Run, C-g Cancel)")
  , ("  (RET 생성, C-g 취소)", "  (RET Create, C-g Cancel)")
  , ("삭제 확인: ", "Confirm delete: ")
  , ("  (y 삭제, 다른 키 취소)", "  (y Delete, other key Cancel)")
  , ("보임", "Shown")
  , ("숨김", "Hidden")
  , ("  숨김 파일: ", "  Hidden files: ")
  , ("보기: ", "View: ")
  , ("C-p/n 스크롤  C-v/M-v 페이지  M-</> 처음/끝  C-g/C-x k 닫기  C-x C-c 종료", "C-p/n Scroll  C-v/M-v Page  M-</> Start/End  C-g/C-x k Close  C-x C-c Quit")
  , ("F2 한국어", "F2 English")
  , ("준비", "Ready")
  , ("알 수 없는 C-x 명령", "Unknown C-x command")
  , ("취소했습니다", "Cancelled")
  , ("특수 파일은 열 수 없습니다", "Cannot open special files")
  , ("바이너리 파일은 미리 볼 수 없습니다", "Cannot preview binary files")
  , ("유효한 대상 경로를 입력하세요", "Enter a valid destination path")
  , ("디렉터리를 만들었습니다", "Directory created")
  , ("복사했습니다", "Copied")
  , ("이동했습니다", "Moved")
  , ("삭제했습니다", "Deleted")
  , ("삭제를 취소했습니다", "Deletion cancelled")
  , ("파일이 존재하지 않습니다", "File does not exist")
  , ("파일 접근 권한이 없습니다", "Permission denied")
  , ("원본과 대상 경로가 같습니다", "Source and destination paths are the same")
  , ("대상 경로가 이미 존재합니다", "Destination already exists")
  , ("대상 상위 디렉터리가 없습니다", "Destination parent directory does not exist")
  , ("디렉터리를 자기 내부로 복사하거나 이동할 수 없습니다", "Cannot copy or move a directory into itself")
  , ("특수 파일은 복사할 수 없습니다", "Cannot copy special files")
  ]
