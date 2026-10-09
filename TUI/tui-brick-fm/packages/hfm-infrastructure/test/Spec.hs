module Main (main) where

import Control.Exception (bracket)
import Hfm.Domain.Config
import Hfm.Infrastructure.Config
  ( decodeKeyBindingConfig, decodeSettings, loadSettingsFrom, saveSettingsTo
  , getSettingsPath, loadSettings, saveSettings )
import Hfm.Domain.Language (Language (..))
import Hfm.Domain.Theme (Theme (Monokai), themes)
import Hfm.Infrastructure.FileSystem
import qualified Hfm.Infrastructure.Process as Process
import Hfm.Infrastructure.Ports (ioProcesses)
import qualified Hfm.Application.Effects.Ports as Ports
import System.Directory
  ( createDirectory, createDirectoryIfMissing, doesDirectoryExist, doesFileExist, getTemporaryDirectory, getCurrentDirectory, listDirectory
  , removeFile, removePathForcibly, createFileLink, createDirectoryLink
  , getSymbolicLinkTarget, withCurrentDirectory )
import System.FilePath ((</>))
import System.IO (hClose, openTempFile)
import System.Environment (getArgs, getExecutablePath, lookupEnv, setEnv, unsetEnv)
import System.Exit (ExitCode (..), exitWith)
import System.Info (os)
import Test.Hspec

main :: IO ()
main = do
  editor <- lookupEnv "HFM_TEST_EDITOR"
  args <- getArgs
  case (editor, args) of
    (Just code, [path]) -> writeFile path "edited" >> exitWith (if code == "0" then ExitSuccess else ExitFailure 7)
    _ -> hspec spec

withEnvironment :: String -> Maybe String -> IO a -> IO a
withEnvironment name value action = bracket (lookupEnv name <* assign value) assign (const action)
  where
    assign Nothing = unsetEnv name
    assign (Just setting) = setEnv name setting

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
  describe "Persisted editor, language and theme" $ do
    it "uses the configured directory and preserves the legacy keybinding file" $ withFixture $ \dir ->
      withEnvironment "XDG_CONFIG_HOME" (Just dir) $ do
        let folder = dir </> "hfm"
            legacy = folder </> "keybindings.yaml"
            settings = Settings (Just "nvim.exe") English Monokai
        createDirectoryIfMissing True folder
        writeFile legacy "binding_style: vim\n"
        getSettingsPath `shouldReturn` (folder </> "settings.yaml")
        loadSettings `shouldReturn` Right defaultSettings
        saveSettings settings `shouldReturn` Right ()
        loadSettings `shouldReturn` Right settings
        readFile legacy `shouldReturn` "binding_style: vim\n"

    it "uses defaults when settings are missing or optional fields are omitted" $ withFixture $ \dir -> do
      loadSettingsFrom (dir </> "missing" </> "settings.yaml") `shouldReturn` Right defaultSettings
      decodeSettings "{}" `shouldSatisfy` either (const False) (== defaultSettings)
      decodeSettings "editor: '  '\nlanguage: en" `shouldSatisfy`
        either (const False) (== defaultSettings { settingsLanguage = English })

    it "round-trips all themes and languages, Unicode paths, and repeated replacement" $ withFixture $ \dir -> do
      let path = dir </> "config" </> "settings.yaml"
      mapM_ (\(theme, language) -> do
        let settings = Settings (Just "C:\\한글 공백\\editor.exe") language theme
        saveSettingsTo path settings `shouldReturn` Right ()
        loadSettingsFrom path `shouldReturn` Right settings) [(theme, language) | theme <- themes, language <- [Korean, English]]
      saveSettingsTo path defaultSettings `shouldReturn` Right ()
      loadSettingsFrom path `shouldReturn` Right defaultSettings
      listDirectory (dir </> "config") `shouldReturn` ["settings.yaml"]

    it "reports malformed or unsupported settings without overwriting them" $ withFixture $ \dir -> do
      let path = dir </> "settings.yaml"
      mapM_ (\contents -> do
        writeFile path contents
        result <- loadSettingsFrom path
        result `shouldSatisfy` either (const True) (const False)
        readFile path `shouldReturn` contents)
        ["[", "language: fr", "theme: unknown", "editor: 42", "editor: \"bad\\0editor\""]

    it "preserves previous settings on failed validation and cleans a failed replacement" $ withFixture $ \dir -> do
      let path = dir </> "settings.yaml"
      saveSettingsTo path defaultSettings `shouldReturn` Right ()
      failed <- saveSettingsTo path (defaultSettings { settingsEditor = Just "bad\0editor" })
      failed `shouldSatisfy` either (const True) (const False)
      loadSettingsFrom path `shouldReturn` Right defaultSettings
      let blocked = dir </> "blocked.yaml"
      createDirectory blocked
      writeFile (blocked </> "keep") "keep"
      replaced <- saveSettingsTo blocked defaultSettings
      replaced `shouldSatisfy` either (const True) (const False)
      readFile (blocked </> "keep") `shouldReturn` "keep"
      remaining <- listDirectory dir
      remaining `shouldMatchList` ["settings.yaml", "blocked.yaml"]

  describe "External editor and shell process ports" $ do
    it "runs commands in the supplied directory and preserves the app cwd" $ withFixture $ \dir -> do
      originalDirectory <- getCurrentDirectory
      let command = if os == "mingw32"
            then "[System.IO.File]::WriteAllText((Join-Path (Get-Location) 'command file.txt'), 'hello')"
            else "printf hello > 'command file.txt'"
      Process.runCommand dir command `shouldReturn` 0
      readFile (dir </> "command file.txt") `shouldReturn` "hello"
      -- Each process gets its own cwd; no global directory change leaks into the app.
      Process.runCommand dir "exit 7" `shouldReturn` 7
      getCurrentDirectory `shouldReturn` originalDirectory

    it "captures launch failures and rejects empty or NUL commands" $ withFixture $ \dir -> do
      result <- Ports.runCommand ioProcesses (dir </> "missing") "exit 0"
      result `shouldSatisfy` either (const True) (const False)
      mapM_ (\command -> Process.runCommand dir command `shouldThrow` anyIOException) ["", " \t ", "echo\0bad"]

    it "passes the entire Unicode filename to the configured editor and returns its exit code" $ withFixture $ \dir -> do
      executable <- getExecutablePath
      let path = dir </> "한글 공백 ' ; & 파일.txt"
      writeFile path "original"
      withEnvironment "VISUAL" (Just executable) $
        withEnvironment "EDITOR" (Just "missing-editor") $
        withEnvironment "HFM_TEST_EDITOR" (Just "0") $
          Process.editFile Nothing dir path `shouldReturn` 0
      readFile path `shouldReturn` "edited"
      withEnvironment "VISUAL" Nothing $
        withEnvironment "EDITOR" (Just executable) $
        withEnvironment "HFM_TEST_EDITOR" (Just "7") $
          Process.editFile Nothing dir path `shouldReturn` 7

    it "does not create a missing file or treat a directory as a file" $ withFixture $ \dir -> do
      Process.editFile Nothing dir (dir </> "missing") `shouldThrow` anyIOException
      Process.editFile Nothing dir dir `shouldThrow` anyIOException
      doesFileExist (dir </> "missing") `shouldReturn` False

    it "uses the saved editor ahead of VISUAL and EDITOR" $ withFixture $ \dir -> do
      executable <- getExecutablePath
      let path = dir </> "한글 공백.txt"
      writeFile path "original"
      withEnvironment "VISUAL" (Just "missing-visual") $
        withEnvironment "EDITOR" (Just "missing-editor") $
        withEnvironment "HFM_TEST_EDITOR" (Just "0") $
          Process.editFile (Just executable) dir path `shouldReturn` 0
      readFile path `shouldReturn` "edited"

    it "reports a missing editor without changing the file" $ withFixture $ \dir -> do
      let path = dir </> "file.txt"
      writeFile path "keep"
      withEnvironment "VISUAL" (Just (dir </> "missing-editor")) $ do
        result <- Ports.editFile ioProcesses Nothing dir path
        result `shouldSatisfy` either (const True) (const False)
      readFile path `shouldReturn` "keep"

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

    it "keeps the parent entry when listing the relative current directory" $ withFixture $ \dir ->
      withCurrentDirectory dir $ do
        entries <- readEntries False "."
        map entryName entries `shouldBe` [".."]

  describe "파일 작업" $ do
    it "디렉터리를 재귀 복사하고 심볼릭 링크를 그대로 복사한다" $ withFixture $ \dir -> do
      let source = dir </> "source"
          target = dir </> "target"
      createDirectory source
      writeFile (source </> "file.txt") "contents"
      createFileLink "file.txt" (source </> "link")
      copyEntry source target
      readFile (target </> "file.txt") `shouldReturn` "contents"
      getSymbolicLinkTarget (target </> "link") `shouldReturn` "file.txt"

    it "dangling links occupy destinations and deletion preserves directory link targets" $ withFixture $ \dir -> do
      let folder = dir </> "folder"
          link = dir </> "link"
          broken = dir </> "broken"
      createDirectory folder
      writeFile (folder </> "keep.txt") "keep"
      createDirectoryLink folder link
      createFileLink "missing.txt" broken
      pathExists broken `shouldReturn` True
      copyEntry (folder </> "keep.txt") broken `shouldThrow` anyIOException
      deleteEntry link
      readFile (folder </> "keep.txt") `shouldReturn` "keep"
      deleteEntry broken
      pathExists broken `shouldReturn` False

    it "copies and deletes dangling directory links without following them" $ withFixture $ \dir -> do
      let source = dir </> "source-link"
          target = dir </> "target-link"
      createDirectoryLink "missing-folder" source
      copyEntry source target
      getSymbolicLinkTarget target `shouldReturn` "missing-folder"
      deleteEntry source
      deleteEntry target
      pathExists target `shouldReturn` False

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
