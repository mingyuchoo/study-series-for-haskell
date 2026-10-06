{-# LANGUAGE OverloadedStrings #-}

import Control.Exception (bracket)
import qualified Data.Vector as Vec
import Brick.Main (renderWidget)
import qualified Data.Text as T
import qualified Data.Text.Lazy as TL
import UI (drawUI)
import Graphics.Vty.PictureToSpans (displayOpsForPic)
import Graphics.Vty.Span (SpanOp (..))
import Brick.Widgets.List (listElements, listSelectedElement)
import FileManager
import Event (editText)
import Config (KeyBindingStyle (..))
import Data.Yaml (ParseException, decodeEither')
import Fuzzy (filterItems, fuzzyMatchScore)
import qualified Graphics.Vty as V
import System.Directory
  ( createDirectory, doesDirectoryExist, doesFileExist, getTemporaryDirectory
  , removeFile, removePathForcibly
  )
import System.FilePath ((</>))
import System.IO (hClose, openTempFile)
import System.Posix.Files (createSymbolicLink, readSymbolicLink)
import Test.Hspec
import Types
import qualified SyntaxHighlightSpec

main :: IO ()
main = hspec spec

withFixture :: (FilePath -> IO a) -> IO a
withFixture action = do
  temp <- getTemporaryDirectory
  bracket (do
      (path, handle) <- openTempFile temp "hfm-test"
      hClose handle
      removeFile path
      createDirectory path
      pure path)
    removePathForcibly action

viewerRows :: AppState -> [T.Text]
viewerRows st =
  let size = stTerminalSize st
      picture = renderWidget Nothing (drawUI st) size
      spanText (TextSpan _ _ _ value) = TL.toStrict value
      spanText (Skip count) = T.replicate count " "
      spanText (RowEnd count) = T.replicate count " "
  in map (T.concat . map spanText . Vec.toList) (Vec.toList (displayOpsForPic picture size))

spec :: Spec
spec = do
  describe "파일 보기 하단 렌더링" $ do
    it "좁은 터미널에서도 하단 안내의 종료 키까지 표시한다" $ do
      let st = (initialState "/tmp" [] "/tmp" [] defaultConfig (40, 12))
                 { stMode = ViewFile "/tmp/test.txt" "first\nlast" 0 }
      T.unlines (viewerRows st) `shouldSatisfy` T.isInfixOf "종료"

    it "화면 크기와 접두 명령에 관계없이 안내 문구와 마지막 줄을 분리한다" $ do
      let content = T.unlines ["LINE-" <> T.pack (show n) | n <- [0 :: Int .. 59]]
      mapM_ (\(size, prefixPending) -> do
        let st = (initialState "/tmp" [] "/tmp" [] defaultConfig size)
                   { stMode = ViewFile "/tmp/test.txt" content 999, stPendingCtrlX = prefixPending }
            rows = viewerRows st
            footerStart = snd size - length (viewerHelpLines st)
        map T.strip (drop footerStart rows) `shouldBe` viewerHelpLines st
        rows !! (footerStart - 2) `shouldSatisfy` T.isInfixOf "LINE-59"
        rows !! (footerStart - 1) `shouldSatisfy` T.isPrefixOf "└")
        [(size, prefixPending) | size <- [(40, 12), (60, 10), (80, 24), (120, 30)], prefixPending <- [False, True]]
    it "빈 줄도 한 행을 차지해 파일 줄 위치를 보존한다" $ do
      let st = (initialState "/tmp" [] "/tmp" [] defaultConfig (40, 12))
                 { stMode = ViewFile "/tmp/test.txt" "first\n\nthird" 0 }
          rows = viewerRows st
      rows !! 2 `shouldSatisfy` T.isInfixOf "first"
      T.strip (rows !! 3) `shouldBe` "│                                      │"
      rows !! 4 `shouldSatisfy` T.isInfixOf "third"
    it "크기를 늘려도 마지막 페이지 위쪽이 비지 않고 끝까지 보인다" $ do
      let content = T.unlines ["LINE-" <> T.pack (show n) | n <- [0 :: Int .. 59]]
          small = initialState "/tmp" [] "/tmp" [] defaultConfig (40, 12)
          oldOffset = clampViewerOffset small content 999
          large = small { stTerminalSize = (80, 24), stMode = ViewFile "/tmp/test.txt" content oldOffset }
          rows = viewerRows large
      rows !! 2 `shouldSatisfy` T.isInfixOf "LINE-40"
      rows !! 21 `shouldSatisfy` T.isInfixOf "LINE-59"
      clampViewerOffset large content 999 `shouldBe` 40
    it "내용 영역이 없는 작은 높이에서도 음수 크기로 렌더링하지 않는다" $ do
      let st = (initialState "/tmp" [] "/tmp" [] defaultConfig (40, 4))
                 { stMode = ViewFile "/tmp/test.txt" "last" 0 }
      viewerContentHeight st `shouldBe` 0
      length (viewerRows st) `shouldBe` 4

  describe "Emacs 입력 편집" $ do
    it "커서를 이동해 중간에 입력하고 앞뒤 글자를 지운다" $ do
      editText (V.EvKey (V.KChar 'b') [V.MCtrl]) "ab" 2 `shouldBe` Just ("ab", 1)
      editText (V.EvKey (V.KChar 'x') []) "ab" 1 `shouldBe` Just ("axb", 2)
      editText (V.EvKey (V.KChar 'h') [V.MCtrl]) "axb" 2 `shouldBe` Just ("ab", 1)
      editText (V.EvKey (V.KChar 'd') [V.MCtrl]) "axb" 1 `shouldBe` Just ("ab", 1)
    it "처음과 끝으로 이동하고 단어 및 커서 뒤를 지운다" $ do
      editText (V.EvKey (V.KChar 'a') [V.MCtrl]) "alpha beta" 5 `shouldBe` Just ("alpha beta", 0)
      editText (V.EvKey (V.KChar 'e') [V.MCtrl]) "alpha beta" 5 `shouldBe` Just ("alpha beta", 10)
      editText (V.EvKey (V.KChar 'w') [V.MCtrl]) "alpha beta" 10 `shouldBe` Just ("alpha ", 6)
      editText (V.EvKey (V.KChar 'w') [V.MCtrl]) "/tmp/file" 9 `shouldBe` Just ("/tmp/", 5)
      editText (V.EvKey (V.KChar 'k') [V.MCtrl]) "alpha beta" 6 `shouldBe` Just ("alpha ", 6)
      editText (V.EvKey (V.KChar 'u') [V.MCtrl]) "alpha beta" 4 `shouldBe` Nothing
    it "Meta 단어 이동과 삭제를 Alt로도 처리한다" $ do
      editText (V.EvKey (V.KChar 'b') [V.MMeta]) "alpha beta" 10 `shouldBe` Just ("alpha beta", 6)
      editText (V.EvKey (V.KChar 'f') [V.MAlt]) "/tmp/file" 0 `shouldBe` Just ("/tmp/file", 4)
      editText (V.EvKey (V.KChar 'd') [V.MAlt]) "alpha beta" 5 `shouldBe` Just ("alpha", 5)
      editText (V.EvKey V.KBS [V.MMeta]) "/tmp/file" 9 `shouldBe` Just ("/tmp/", 5)
    it "입력 경계와 한글 커서를 처리한다" $ do
      editText (V.EvKey (V.KChar 'b') [V.MMeta]) "" 0 `shouldBe` Just ("", 0)
      editText (V.EvKey (V.KChar 'f') [V.MMeta]) "abc" 3 `shouldBe` Just ("abc", 3)
      editText (V.EvKey (V.KChar 'd') [V.MCtrl]) "가나다" 1 `shouldBe` Just ("가다", 1)
      editText (V.EvKey V.KHome []) "abc" 2 `shouldBe` Just ("abc", 0)
      editText (V.EvKey V.KEnd []) "abc" 1 `shouldBe` Just ("abc", 3)

  describe "Emacs 설정 통일" $ do
    it "이전 Vim 설정과 알 수 없는 설정을 Emacs로 읽는다" $ do
      (decodeEither' "\"vim\"" :: Either ParseException KeyBindingStyle) `shouldSatisfy` either (const False) (== Emacs)
      (decodeEither' "\"vi\"" :: Either ParseException KeyBindingStyle) `shouldSatisfy` either (const False) (== Emacs)
      (decodeEither' "\"other\"" :: Either ParseException KeyBindingStyle) `shouldSatisfy` either (const False) (== Emacs)

  describe "패널 탐색" $ do
    it "디렉터리를 먼저 정렬하고 숨김 파일을 전환한다" $ withFixture $ \dir -> do
      createDirectory (dir </> "z-folder")
      writeFile (dir </> "a.txt") "hello"
      writeFile (dir </> ".secret") "hidden"
      normal <- readEntries False dir
      map entryName normal `shouldBe` ["..", "z-folder", "a.txt"]
      allEntries <- readEntries True dir
      map entryName allEntries `shouldBe` ["..", "z-folder", ".secret", "a.txt"]

    it "검색에서 부모 항목을 유지하고 선택을 복원한다" $ do
      let entries = [Entry ".." Parent 0, Entry "alpha" RegularFile 1, Entry "beta" RegularFile 1]
          st = initialState "/tmp" entries "/tmp" entries defaultConfig (80, 24)
          panel = stLeft st
          filtered = refreshPanel entries (Just "beta") (panel { panelSearch = "BETA" })
      map entryName (Vec.toList (listElements (panelEntries filtered))) `shouldBe` ["..", "beta"]
      fmap (entryName . snd) (listSelectedElement (panelEntries filtered)) `shouldBe` Just "beta"

  describe "파일 작업" $ do
    it "디렉터리를 재귀 복사하고 심볼릭 링크를 그대로 복사한다" $ withFixture $ \dir -> do
      let source = dir </> "source"
          target = dir </> "target"
      createDirectory source
      writeFile (source </> "file.txt") "contents"
      createSymbolicLink "file.txt" (source </> "link")
      copyEntry source target
      readFile (target </> "file.txt") `shouldReturn` "contents"
      readSymbolicLink (target </> "link") `shouldReturn` "file.txt"

    it "기존 대상은 덮어쓰지 않는다" $ withFixture $ \dir -> do
      let source = dir </> "source"
          target = dir </> "target"
      writeFile source "source"
      writeFile target "target"
      copyEntry source target `shouldThrow` anyIOException
      moveEntry source target `shouldThrow` anyIOException
      readFile target `shouldReturn` "target"

    it "디렉터리를 자기 내부로 복사하지 않는다" $ withFixture $ \dir -> do
      let source = dir </> "source"
      createDirectory source
      copyEntry source (source </> "nested") `shouldThrow` anyIOException
      doesDirectoryExist (source </> "nested") `shouldReturn` False

    it "이동과 재귀 삭제를 처리한다" $ withFixture $ \dir -> do
      let source = dir </> "source"
          target = dir </> "target"
      createDirectory source
      writeFile (source </> "file.txt") "contents"
      moveEntry source target
      doesDirectoryExist source `shouldReturn` False
      doesFileExist (target </> "file.txt") `shouldReturn` True
      deleteEntry target
      doesDirectoryExist target `shouldReturn` False

    it "디렉터리 대상 입력은 원본 이름을 붙인다" $ withFixture $ \dir -> do
      let source = dir </> "file.txt"
      destinationFor dir source dir `shouldReturn` (dir </> "file.txt")

  describe "기존 검색 함수" $ do
    it "퍼지 일치를 계산한다" $ fuzzyMatchScore "ts" "test" `shouldBe` Just 1
    it "검색 결과를 필터링한다" $ Vec.length (filterItems "ab" (Vec.fromList ["abc", "xyz"])) `shouldBe` 1

  SyntaxHighlightSpec.spec
