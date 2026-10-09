{-# LANGUAGE OverloadedStrings #-}

module Hfm.Tui.I18n (translate, renderStatus, renderFileError) where

import qualified Data.Text as T

import Hfm.Application.Error (FileError (..))
import Hfm.Application.Status (Status (..))
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

renderStatus :: Language -> Status -> T.Text
renderStatus language status = case status of
  CurrentDirectory path -> T.pack path
  Failed err -> translate language "오류: " <> renderFileError language err
  Ready -> translate language "준비"
  UnknownCommand -> translate language "알 수 없는 C-x 명령"
  Cancelled -> translate language "취소했습니다"
  SpecialFileUnsupported -> translate language "특수 파일은 열 수 없습니다"
  BinaryPreviewUnsupported -> translate language "바이너리 파일은 미리 볼 수 없습니다"
  InvalidDestination -> translate language "유효한 대상 경로를 입력하세요"
  DirectoryCreated -> translate language "디렉터리를 만들었습니다"
  Copied -> translate language "복사했습니다"
  Moved -> translate language "이동했습니다"
  Deleted -> translate language "삭제했습니다"
  DeletionCancelled -> translate language "삭제를 취소했습니다"
  EditorFinished code -> translate language "편집기 종료 코드: " <> T.pack (show code)
  CommandFinished code -> translate language "명령 종료 코드: " <> T.pack (show code)
  InvalidCommand -> translate language "유효한 명령어를 입력하세요"
  InvalidEditor -> translate language "편집기 경로에는 줄바꿈이나 NUL을 넣을 수 없습니다"
  SettingsSaved -> translate language "설정을 저장했습니다"
  SettingsSaveFailed err -> translate language "설정 저장 실패: " <> renderFileError language err

renderFileError :: Language -> FileError -> T.Text
renderFileError language err = translate language $ case err of
  Missing -> "파일이 존재하지 않습니다"
  PermissionDenied -> "파일 접근 권한이 없습니다"
  FileFailure detail -> detail

translations :: [(T.Text, T.Text)]
translations =
  [ ("hfm  |  파일 관리자", "hfm  |  File manager")
  , ("C-x: C-c 종료  o 패널  C-f 열기  k 닫기  C-g 취소", "C-x: C-c Quit  o Panel  C-f Open  k Close  C-g Cancel")
  , ("C-x: C-c 종료  k 닫기  C-g 명령 취소", "C-x: C-c Quit  k Close  C-g Cancel command")
  , ("C-s/r 다음/이전  C-p/n 이동  C-v/M-v 페이지  C-g 취소", "C-s/r Next/Prev  C-p/n Move  C-v/M-v Page  C-g Cancel")
  , ("C-a/e 처음/끝  C-b/f 문자  M-b/f 단어  C-k/M-d 삭제", "C-a/e Start/End  C-b/f Char  M-b/f Word  C-k/M-d Delete")
  , ("y 삭제  n/C-g 취소", "y Delete  n/C-g Cancel")
  , ("C-p/n 이동  C-v/M-v 페이지  M-</> 처음/끝  C-x o 패널  C-x C-c 종료", "C-p/n Move  C-v/M-v Page  M-</> Start/End  C-x o Panel  C-x C-c Quit")
  , ("C-s 검색  RET 열기  v 보기  e 편집  C 복사  R 이동  r 이름  + 폴더  D 삭제  ! 명령", "C-s Search  RET Open  v View  e Edit  C Copy  R Move  r Rename  + Folder  D Delete  ! Command")
  , ("검색: ", "Search: ")
  , ("  (RET 적용, C-g 취소)", "  (RET Apply, C-g Cancel)")
  , ("복사 대상: ", "Copy to: ")
  , ("이동/새 이름: ", "Move/rename to: ")
  , ("새 이름: ", "New name: ")
  , ("명령어: ", "Command: ")
  , ("새 폴더: ", "New folder: ")
  , ("  (RET 실행, C-g 취소)", "  (RET Run, C-g Cancel)")
  , ("  (RET 생성, C-g 취소)", "  (RET Create, C-g Cancel)")
  , ("삭제 확인: ", "Confirm delete: ")
  , ("  (하위 내용 포함, y 삭제, 다른 키 취소)", "  (including contents, y Delete, other key Cancel)")
  , ("Enter를 누르면 파일 관리자로 돌아갑니다.", "Press Enter to return to the file manager.")
  , ("편집기 종료 코드: ", "Editor exit code: ")
  , ("명령 종료 코드: ", "Command exit code: ")
  , ("유효한 명령어를 입력하세요", "Enter a valid command")
  , ("편집할 일반 파일이 없습니다", "No regular file to edit")
  , ("보임", "Shown")
  , ("숨김", "Hidden")
  , ("  숨김 파일: ", "  Hidden files: ")
  , ("보기: ", "View: ")
  , ("C-p/n 스크롤  C-v/M-v 페이지  M-</> 처음/끝  C-g/C-x k 닫기  C-x C-c 종료", "C-p/n Scroll  C-v/M-v Page  M-</> Start/End  C-g/C-x k Close  C-x C-c Quit")
  , ("F3 테마", "F3 Theme")
  , ("F4 편집기", "F4 Editor")
  , ("편집기: ", "Editor: ")
  , ("  (RET 저장, C-g 취소)", "  (RET Save, C-g Cancel)")
  , ("실행 파일 이름/전체 경로만 입력 (인자 제외). 비우면 환경 변수/기본 편집기 사용", "Executable name/full path only (no arguments). Empty uses environment/default editor")
  , ("편집기 경로에는 줄바꿈이나 NUL을 넣을 수 없습니다", "Editor path cannot contain newlines or NUL")
  , ("설정을 저장했습니다", "Settings saved")
  , ("설정 저장 실패: ", "Failed to save settings: ")
  , ("테마 선택", "Select theme")
  , ("미리보기: ", "Preview: ")
  , ("↑/↓ C-p/n 이동  1-8 선택  RET 적용  Esc/C-g 취소", "↑/↓ C-p/n Move  1-8 Select  RET Apply  Esc/C-g Cancel")
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
