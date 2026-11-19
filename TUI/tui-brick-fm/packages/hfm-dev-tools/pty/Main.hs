module Main (main) where

import           Control.Monad      (forM_, unless, void, when)

import qualified Data.ByteString    as Bytes
import           Data.List          (isInfixOf)
import qualified Data.Text          as Text
import qualified Data.Text.Encoding as Text
import qualified Data.Text.IO       as Text

import           System.Directory   (createDirectory, createDirectoryIfMissing,
                                     doesDirectoryExist, doesFileExist,
                                     getPermissions, makeAbsolute,
                                     setOwnerExecutable, setPermissions)
import           System.Environment (getArgs)
import           System.FilePath    ((</>))
import           System.IO.Temp     (withSystemTempDirectory)

import           Terminal

import           Text.Printf        (printf)

main :: IO ()
main = do
  arguments <- getArgs
  binary <- case arguments of
    [path] -> makeAbsolute path
    _      -> ioError (userError "Usage: hfm-test-keybindings HFM_BINARY")
  withSystemTempDirectory "hfm-keys-" $ \base -> do
    let left = base </> "left"
        right = base </> "right"
        config = base </> "config"
    mapM_ createDirectory [left, right]
    createDirectoryIfMissing True (config </> "hfm")
    writeUtf8 (config </> "hfm/keybindings.yaml") "binding_style: vim\n"
    forM_ [0 .. 39 :: Int] $ \index ->
      writeUtf8 (left </> printf "file-%02d.txt" index) (unlines [printf "LINE-%03d" line | line <- [0 .. 59 :: Int]])
    writeUtf8 (left </> ".secret") "hidden"
    forM_ [1 .. 10 :: Int] $ \_ -> withTerminal binary left right config Nothing quit
    navigation binary left right config
    let externalLeft = base </> "external-left"
        externalRight = base </> "external-right"
        editor = base </> "test editor"
        editFile = externalLeft </> "edit file ' &.txt"
    mapM_ createDirectory [externalLeft, externalRight]
    writeUtf8 editFile "original"
    writeUtf8 editor "#!/bin/sh\nprintf edited > \"$1\"\nprintf editor > editor-cwd.txt\n"
    permissions <- getPermissions editor
    setPermissions editor (setOwnerExecutable True permissions)
    externalPrograms binary externalLeft externalRight config editor editFile
    languageModes binary left right config
    themes binary left right config
    forM_ ["\DC3", "+draft", "\SO\&D", "\SOv", "\ESCOS"] $ \mode ->
      withTerminal binary left right config Nothing $ \terminal -> void (key terminal mode) >> quit terminal
    savedSettings binary externalLeft externalRight (base </> "saved-config") editor editFile
    tabRendering binary base right config
  putStrLn "PTY keybindings passed: legacy config, navigation, viewer, search, file operations, saved editor/language/theme, all eight themes, modal quit, themed tab rendering"

navigation :: FilePath -> FilePath -> FilePath -> FilePath -> IO ()
navigation binary left right config = withTerminal binary left right config Nothing $ \terminal -> do
  void (key terminal "qjklh/\t")
  expect terminal "\ESC>" "file-39.txt"
  expect terminal "\ESC<" "file-00.txt"
  expect terminal "\SO\CAN\ACK" "LINE-000"
  expect terminal "\SYN" "LINE-020"
  expect terminal "\ESCv" "LINE-000"
  expect terminal "\ESC>" "LINE-059"
  expect terminal "\ESC<" "LINE-000"
  expect terminal "\CANk" "파일 관리자"
  expect terminal "\ESCo" ".secret"
  void (key terminal "\ESCo")
  void (key terminal "\DC3file-\ESC<\DC3\DC3\DC2\r")
  expect terminal "v" "file-00.txt"
  void (key terminal "\BEL\BEL")
  void (key terminal "\DC3file-00\SO\r")
  void (key terminal "C\r")
  assertFile (right </> "file-00.txt") True
  void (key terminal "R\SOH\VT")
  void (key terminal ((right </> "renamed.txt") ++ "\r"))
  assertFile (right </> "renamed.txt") True
  assertFile (left </> "file-00.txt") False
  void (key terminal "\BEL\CANo+new-folder\r")
  assertDirectory (right </> "new-folder") True
  void (key terminal "\CANo\DC3file-01\SO\rD\BEL")
  assertFile (left </> "file-01.txt") True
  void (key terminal "Dy")
  assertFile (left </> "file-01.txt") False
  quit terminal

externalPrograms :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> IO ()
externalPrograms binary left right config editor editFile = withTerminal binary left right config (Just editor) $ \terminal -> do
  expect terminal "\SOe" "편집기 종료 코드: 0"
  assertContents editFile "edited"
  assertContents (left </> "editor-cwd.txt") "editor"
  expect terminal "!printf SHELL-OK; printf command > command.txt\r" "SHELL-OK"
  assertContents (left </> "command.txt") "command"
  expect terminal "\r" "명령 종료 코드: 0"
  void (key terminal "!read value; printf '%s' \"$value\" > input.txt\r")
  expect terminal "interactive-input\r" "Enter"
  expect terminal "\r" "명령 종료 코드: 0"
  assertContents (left </> "input.txt") "interactive-input"
  expect terminal "!exit 7\r" "Enter"
  expect terminal "\r" "명령 종료 코드: 7"
  void (key terminal "+old-folder\r\DC3old-folder\SO\re\SOH\VTnew-folder\r")
  assertDirectory (left </> "new-folder") True
  assertDirectory (left </> "old-folder") False
  void (key terminal "\BEL\DC3new-folder\SO\rDy")
  assertDirectory (left </> "new-folder") False
  quit terminal

languageModes :: FilePath -> FilePath -> FilePath -> FilePath -> IO ()
languageModes binary left right config = forM_ modes $ \(mode, english) ->
  withTerminal binary left right config Nothing $ \terminal -> do
    void (key terminal mode)
    expect terminal "\ESCOQ" english
    expect terminal "\ESCOQ" "한국어"
    when (mode == "\CAN") (void (key terminal "\BEL"))
    void (key terminal "\BEL")
    quit terminal
    assertDirectory (left </> "draft") False
    assertFile (left </> "file-02.txt") True
  where
    modes = [("", "File manager"), ("\DC3file-", "Search:"), ("+draft", "New folder:"), ("\SO\&C", "Copy to:"), ("\SO\&R", "Move/rename to:"), ("\SO\&D", "Confirm delete:"), ("\SOv", "View:"), ("\CAN", "C-x:")]

themes :: FilePath -> FilePath -> FilePath -> FilePath -> IO ()
themes binary left right config = withTerminal binary left right config Nothing $ \terminal -> do
  forM_ (zip [1 :: Int ..] ["Light", "Dark", "Monokai", "Solarized Light", "Solarized Dark", "Tomorrow Night Blue", "Gruvbox Dark", "Gruvbox Light"]) $ \(number, theme) -> do
    expect terminal "\ESCOR" "테마 선택"
    expect terminal (show number) ("미리보기: " ++ theme)
    expect terminal "\r" theme
  void (key terminal "+draft")
  expect terminal "\ESCOR" "테마 선택"
  expect terminal "3" "Monokai"
  expect terminal "\ESC" "draft"
  void (key terminal "\BEL")
  expect terminal "\ESCOR" "테마 선택"
  expect terminal "\ESCOQ" "Select theme"
  void (key terminal "\BEL")
  quit terminal
  assertDirectory (left </> "draft") False

savedSettings :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> IO ()
savedSettings binary left right config editor editFile = do
  let settings = config </> "hfm/settings.yaml"
  withTerminal binary left right config (Just "missing-editor") $ \terminal -> do
    expect terminal "\ESCOS" "편집기:"
    expect terminal (editor ++ "\r") "설정을 저장했습니다"
    expect terminal "\ESCOQ" "File manager"
    void (key terminal "\ESCOR3\r")
    quit terminal
  contents <- Text.unpack <$> Text.readFile settings
  assert (all (`isInfixOf` contents) ["language: en", "theme: monokai", editor]) ("Saved settings are incomplete: " ++ contents)
  withTerminal binary left right config (Just "missing-editor") $ \terminal -> do
    assert (all ((`Bytes.isInfixOf` initialOutput terminal) . encode) ["File manager", "Monokai"]) "Settings were not restored at startup"
    expect terminal "\ESCOS" editor
    void (key terminal "\BEL")
    writeUtf8 editFile "original"
    expect terminal "\DC3edit file\SO\re" "Editor exit code: 0"
    assertContents editFile "edited"
    void (key terminal "\BEL\ESCOS\SOH\VT\r")
    reset <- Text.unpack <$> Text.readFile settings
    assert ("editor: null" `isInfixOf` reset) "Editor reset was not saved"
    quit terminal

tabRendering :: FilePath -> FilePath -> FilePath -> FilePath -> IO ()
tabRendering binary base right config = do
  let left = base </> "tab-left"
  createDirectory left
  writeUtf8 (left </> "Makefile") "target:\n\tstack build\n\t\n가\t값\nx\t\tz\n"
  withTerminal binary left right config Nothing $ \terminal -> do
    output <- key terminal "\SOv"
    assert (encode "stack build" `Bytes.isInfixOf` output) "Viewer did not show the Makefile"
    assert (not (Bytes.elem 9 output)) "Viewer emitted a raw terminal tab"
    forM_ [1 .. 8 :: Int] $ \number -> do
      void (key terminal "\ESCOR")
      void (key terminal (show number))
      redraw <- key terminal "\r"
      assert (not (Bytes.elem 9 redraw)) "Theme redraw emitted a raw terminal tab"
    quit terminal

assert :: Bool -> String -> IO ()
assert condition message = unless condition (ioError (userError message))

assertFile :: FilePath -> Bool -> IO ()
assertFile path expected = do
  exists <- doesFileExist path
  assert (exists == expected) ("Unexpected file state: " ++ path)

assertDirectory :: FilePath -> Bool -> IO ()
assertDirectory path expected = do
  exists <- doesDirectoryExist path
  assert (exists == expected) ("Unexpected directory state: " ++ path)

assertContents :: FilePath -> String -> IO ()
assertContents path expected = do
  contents <- Text.unpack <$> Text.readFile path
  assert (contents == expected) ("Unexpected contents: " ++ path ++ "\n" ++ contents)

writeUtf8 :: FilePath -> String -> IO ()
writeUtf8 path = Text.writeFile path . Text.pack

encode :: String -> Bytes.ByteString
encode = Text.encodeUtf8 . Text.pack
