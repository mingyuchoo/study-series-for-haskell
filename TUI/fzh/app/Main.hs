module Main
    ( main
    ) where
import           Brick              (customMain)
import           Brick.Widgets.List (listSelectedElement)

import           Config             (loadKeyBindingConfig)

import qualified Data.Text          as T

import           FileSearch         (listFilesRecursive)

import           Flow               ((<|))

import           Lib                (AppState (..), app, buildVtyFromTty,
                                     configWithKeyBinding, initialState)

import           System.IO          (hIsTerminalDevice, stdin)

-- 입력 소스 결정: stdin이 파이프면 stdin, 아니면 현재 디렉터리부터 재귀적으로 파일 목록
getInputItems :: IO [T.Text]
getInputItems = do
  isTty <- hIsTerminalDevice stdin
  if isTty
    then do
      -- stdin이 터미널이면 현재 디렉터리부터 재귀적으로 파일 검색
      files <- listFilesRecursive "."
      return <| map T.pack files
    else do
      -- stdin이 파이프면 stdin에서 읽기
      input <- getContents
      return <| map T.pack <| lines input

main :: IO ()
main = do
  items <- getInputItems

  if null items
    then putStrLn "No input provided"
    else do
      -- 키바인딩 설정 로드
      kbConfig <- loadKeyBindingConfig
      let cfg = configWithKeyBinding kbConfig
          -- TODO: Task 6에서 실제 터미널 크기를 획득하도록 수정 예정
          initialSt = initialState items cfg (80, 24)
      -- /dev/tty를 사용하여 TUI 실행
      initialVty <- buildVtyFromTty
      finalState <- customMain initialVty buildVtyFromTty Nothing app initialSt

      -- 선택된 아이템 출력
      let selected = listSelectedElement (stFilteredList finalState)
      case selected of
        Just (_, item) -> putStrLn <| T.unpack item
        Nothing        -> return ()
