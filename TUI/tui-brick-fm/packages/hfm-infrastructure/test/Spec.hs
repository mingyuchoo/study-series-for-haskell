module Main (main) where

import Control.Exception (bracket)
import Hfm.Domain.Config
import Hfm.Infrastructure.Config (decodeKeyBindingConfig)
import Hfm.Infrastructure.FileSystem
import System.Directory
  ( createDirectory, doesDirectoryExist, doesFileExist, getTemporaryDirectory
  , removeFile, removePathForcibly )
import System.FilePath ((</>))
import System.IO (hClose, openTempFile)
import System.Posix.Files (createSymbolicLink, readSymbolicLink)
import Test.Hspec

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

spec :: Spec
spec = do
  describe "Emacs 설정 통일" $ do
    it "이전 Vim 설정과 알 수 없는 설정을 Emacs로 읽는다" $ do
      decodeKeyBindingConfig "binding_style: vim" `shouldSatisfy` either (const False) (== KeyBindingConfig Emacs)
      decodeKeyBindingConfig "binding_style: vi" `shouldSatisfy` either (const False) (== KeyBindingConfig Emacs)
      decodeKeyBindingConfig "binding_style: other" `shouldSatisfy` either (const False) (== KeyBindingConfig Emacs)

  describe "패널 탐색" $ do
    it "디렉터리를 먼저 정렬하고 숨김 파일을 전환한다" $ withFixture $ \dir -> do
      createDirectory (dir </> "z-folder")
      writeFile (dir </> "a.txt") "hello"
      writeFile (dir </> ".secret") "hidden"
      normal <- readEntries False dir
      map entryName normal `shouldBe` ["..", "z-folder", "a.txt"]
      allEntries <- readEntries True dir
      map entryName allEntries `shouldBe` ["..", "z-folder", ".secret", "a.txt"]

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

