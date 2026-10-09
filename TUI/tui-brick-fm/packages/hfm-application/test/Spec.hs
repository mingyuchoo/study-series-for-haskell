{-# LANGUAGE GADTs #-}

module Main (main) where

import Control.Monad.State.Strict (State, modify, runState)
import Hfm.Application.Effects.Ports
import Hfm.Application.Error
import Hfm.Application.State
import Hfm.Application.Program
import Hfm.Application.Startup (planStartup)
import Hfm.Application.Workflow (planInput)
import Hfm.Application.Status
import Hfm.Application.Effects.Runtime
import qualified Data.Vector as Vec
import qualified Data.Text as T
import Hfm.Domain.Entry
import Hfm.Domain.Config (Settings (..), defaultSettings)
import Hfm.Domain.Input
import Hfm.Domain.Theme (themes)
import Hfm.Domain.Selection
import Test.Hspec hiding (before, after, pending)
import System.FilePath ((</>))
import System.Info (os)

main :: IO ()
main = hspec spec

entry :: Entry
entry = Entry "file.txt" RegularFile 4

initial :: AppState
initial = initialState (testPath "left") [entry] (testPath "right") [] defaultConfig (80, 24)

testPath :: FilePath -> FilePath
testPath path = (if os == "mingw32" then "C:\\" else "/") </> path

record :: String -> a -> State [String] (Either FileError a)
record call result = modify (++ [call]) >> pure (Right result)

-- Deterministic memory ports; these tests have no IO or terminal dependency.
memory :: FileSystem (State [String])
memory = FileSystem
  { readEntries = \_ path -> record ("list " ++ path) [entry]
  , canonicalizePath = \path -> record ("resolve " ++ path) path
  , doesDirectoryExist = \path -> record ("is-dir " ++ path) (path == testPath "right")
  , readPreview = \path -> record ("preview " ++ path) "text"
  , copyEntry = \source target -> record ("copy " ++ source ++ " " ++ target) ()
  , moveEntry = \source target -> record ("move " ++ source ++ " " ++ target) ()
  , deleteEntry = \path -> record ("delete " ++ path) ()
  , makeDirectory = \path -> record ("mkdir " ++ path) ()
  }

memoryProcesses :: Processes (State [String])
memoryProcesses = Processes
  { editFile = \_ cwd path -> record ("edit " ++ cwd ++ " " ++ path) 0
  , runCommand = \cwd command -> record ("command " ++ cwd ++ " " ++ T.unpack command) 0
  }

run :: FileSystem (State [String]) -> Input -> AppState -> ((AppState, Bool), [String])
run files = runWith files memoryProcesses

runWith :: FileSystem (State [String]) -> Processes (State [String]) -> Input -> AppState -> ((AppState, Bool), [String])
runWith files processes input state = runState (handleInput files processes (const (pure (Right ()))) input state) []

spec :: Spec
spec = do
  describe "Saved application settings" $ do
    it "restores the editor, language and theme at startup" $ do
      let settings = Settings (Just "nvim.exe") English Monokai
          config = defaultConfig { configSettings = settings }
          state = initialState "left" [] "right" [] config (80, 24)
      currentSettings state `shouldBe` settings
      stLanguage state `shouldBe` English
      stTheme state `shouldBe` Monokai

    it "opens F4 with the current executable and supports editing, saving and resetting" $ do
      let configured = applySettings (defaultSettings { settingsEditor = Just "vi" }) initial
          ((opened, _), _) = run memory (KeyPress (KFun 4) []) configured
          ((edited, _), _) = run memory (KeyPress (KChar 'm') []) opened
          save settings = record (show settings) ()
          ((done, _), calls) = runState (handleInput memory memoryProcesses save (KeyPress KEnter []) edited) []
          ((reset, _), resetCalls) = runState
            (handleInput memory memoryProcesses save (KeyPress KEnter []) (done { stMode = EditorPrompt "  " })) []
      stMode opened `shouldBe` EditorPrompt "vi"
      stMode edited `shouldBe` EditorPrompt "vim"
      settingsEditor (currentSettings done) `shouldBe` Just "vim"
      calls `shouldBe` [show (currentSettings done)]
      stStatus done `shouldBe` SettingsSaved
      settingsEditor (currentSettings reset) `shouldBe` Nothing
      resetCalls `shouldBe` [show (currentSettings reset)]

    it "passes the saved executable through the process port" $ do
      let settings = defaultSettings { settingsEditor = Just "C:\\한글 폴더\\editor.exe" }
          state = applySettings settings initial
          ports = memoryProcesses { editFile = \editor _ _ -> record (show editor) 0 }
          ((_, _), calls) = runWith memory ports (KeyPress (KChar 'e') []) state
      take 1 calls `shouldBe` [show (settingsEditor settings)]

    it "writes an explicitly confirmed editor even when it matches the defaults" $ do
      let save settings = record (show settings) ()
          ((done, _), calls) = runState
            (handleInput memory memoryProcesses save (KeyPress KEnter []) (initial { stMode = EditorPrompt "" })) []
      calls `shouldBe` [show defaultSettings]
      stStatus done `shouldBe` SettingsSaved

    it "saves language immediately and saves only the committed theme" $ do
      let save settings = record (show settings) ()
          step key state = runState (handleInput memory memoryProcesses save key state) []
          ((english, _), languageCalls) = step (KeyPress (KFun 2) []) initial
          ((opened, _), openCalls) = step (KeyPress (KFun 3) []) english
          ((preview, _), previewCalls) = step (KeyPress (KChar '3') []) opened
          ((done, _), themeCalls) = step (KeyPress KEnter []) preview
          ((cancelled, _), cancelCalls) = step (KeyPress KEsc []) preview
      languageCalls `shouldBe` [show (Settings Nothing English Dark)]
      openCalls ++ previewCalls ++ cancelCalls `shouldBe` []
      themeCalls `shouldBe` [show (Settings Nothing English Monokai)]
      currentSettings cancelled `shouldBe` currentSettings english
      currentSettings done `shouldBe` Settings Nothing English Monokai

    it "does not save a theme preview when switching language" $ do
      let save settings = record (show settings) ()
          state = initial { stThemePicker = Just (selectAt 2 (selection themes)) }
          ((done, _), calls) = runState (handleInput memory memoryProcesses save (KeyPress (KFun 2) []) state) []
      calls `shouldBe` [show (Settings Nothing English Dark)]
      stThemePicker done `shouldBe` stThemePicker state

    it "restores previous settings and retains the prompt or picker on a failed save" $ do
      let save _ = pure (Left PermissionDenied)
          states = [(initial, KeyPress (KFun 2) []),
                    (initial { stMode = EditorPrompt "nvim", stInputCursor = 4 }, KeyPress KEnter []),
                    (initial { stThemePicker = Just (selectAt 2 (selection themes)) }, KeyPress KEnter [])]
      mapM_ (\(state, key) -> do
        let ((done, quit), _) = runState (handleInput memory memoryProcesses save key state) []
        currentSettings done `shouldBe` currentSettings state
        stMode done `shouldBe` stMode state
        stInputCursor done `shouldBe` stInputCursor state
        stThemePicker done `shouldBe` stThemePicker state
        stStatus done `shouldBe` SettingsSaveFailed PermissionDenied
        quit `shouldBe` False) states

    it "cancels editor changes and rejects NUL or newline input without saving" $ do
      let save _ = error "Unexpected settings write"
          step key state = runState (handleInput memory memoryProcesses save key state) []
          prompt = initial { stMode = EditorPrompt "nvim" }
      mapM_ (\key -> do
        let ((done, _), _) = step key prompt
        currentSettings done `shouldBe` defaultSettings
        stMode done `shouldBe` Browse) [KeyPress KEsc [], KeyPress (KChar 'g') [MCtrl]]
      mapM_ (\value -> do
        let ((done, _), _) = step (KeyPress KEnter []) (initial { stMode = EditorPrompt value })
        stStatus done `shouldBe` InvalidEditor
        stMode done `shouldBe` EditorPrompt value) ["bad\0editor", "bad\neditor", "bad\reditor"]

  describe "Independent effect ports" $ do
    it "runs a file plan without accessing process ports" $ do
      let unavailable = Processes
            { editFile = \_ _ _ -> error "Unexpected editor request"
            , runCommand = \_ _ -> error "Unexpected command request"
            }
          ((done, _), calls) = runWith memory unavailable (KeyPress (KChar 'g') []) initial
      calls `shouldBe` ["list " ++ testPath "left", "list " ++ testPath "right"]
      stStatus done `shouldBe` Ready

    it "runs a process request without accessing file ports" $ do
      let (result, calls) = runState
            (runProgram (error "Unexpected file port access") memoryProcesses
              (request (RunCommand (testPath "left") "exit 0"))) []
      result `shouldBe` Right 0
      calls `shouldBe` ["command " ++ testPath "left" ++ " exit 0"]

  describe "Editing, directory renaming and shell commands" $ do
    it "edits the selected file and refreshes both panels" $ do
      let ((done, _), calls) = run memory (KeyPress (KChar 'e') []) initial
      calls `shouldBe` ["edit " ++ testPath "left" ++ " " ++ testPath ("left" </> "file.txt"),
                        "list " ++ testPath "left", "list " ++ testPath "right"]
      stMode done `shouldBe` Browse
      stStatus done `shouldBe` EditorFinished 0

    it "renames a directory in place from either r or e" $ do
      let folder = initialState (testPath "left") [Entry "folder" Directory 0] (testPath "right") [] defaultConfig (80, 24)
      mapM_ (\key -> do
        let ((prompt, _), calls) = run memory (KeyPress (KChar key) []) folder
            ((done, _), renamed) = run memory (KeyPress KEnter []) (prompt { stMode = Prompt Rename "new-folder" })
        stMode prompt `shouldBe` Prompt Rename "folder"
        stInputCursor prompt `shouldBe` 6
        calls `shouldBe` []
        renamed `shouldBe` ["move " ++ testPath ("left" </> "folder") ++ " " ++ testPath ("left" </> "new-folder"),
                            "list " ++ testPath "left", "list " ++ testPath "right"]
        stStatus done `shouldBe` Moved) ['r', 'e']

    it "protects parent and special entries from editing and renaming" $ do
      mapM_ (\kind -> mapM_ (\key -> do
        let state = initialState (testPath "left") [Entry ".." kind 0] (testPath "right") [] defaultConfig (80, 24)
            ((done, _), calls) = run memory (KeyPress (KChar key) []) state
        stMode done `shouldBe` Browse
        calls `shouldBe` []) ['e', 'r']) [Parent, Special]

    it "rejects rename paths and retains the prompt after a collision" $ do
      mapM_ (\name -> do
        let ((done, _), calls) = run memory (KeyPress KEnter []) (initial { stMode = Prompt Rename name })
        stStatus done `shouldBe` InvalidDestination
        calls `shouldBe` []) ["", ".", "..", "folder/name", T.pack (testPath "absolute")]
      let ports = memory { moveEntry = \_ _ -> pure (Left PermissionDenied) }
          state = initial { stMode = Prompt Rename "taken" }
          ((done, _), calls) = run ports (KeyPress KEnter []) state
      stMode done `shouldBe` stMode state
      stStatus done `shouldBe` Failed PermissionDenied
      calls `shouldBe` []

    it "opens a command prompt even without a selection and cancels without effects" $ do
      let empty = initialState (testPath "left") [] (testPath "right") [] defaultConfig (80, 24)
      mapM_ (\input -> do
        let ((prompt, _), calls) = run memory input empty
            ((cancelled, _), cancelledCalls) = run memory (KeyPress (KChar 'g') [MCtrl]) prompt
        stMode prompt `shouldBe` Prompt Command ""
        calls `shouldBe` []
        stMode cancelled `shouldBe` Browse
        cancelledCalls `shouldBe` []) [KeyPress (KChar '!') [], KeyPress (KChar '!') [MMeta], KeyPress (KChar '!') [MAlt]]

    it "runs the unchanged command in the active panel and reports a nonzero exit" $ do
      let command = "  echo '한글 이름' > output.txt  "
          ports = memoryProcesses { runCommand = \cwd value -> record ("command " ++ cwd ++ " " ++ T.unpack value) 7 }
          state = initial { stActive = RightSide, stMode = Prompt Command command }
          ((done, _), calls) = runWith memory ports (KeyPress KEnter []) state
      calls `shouldBe` ["command " ++ testPath "right" ++ " " ++ T.unpack command,
                        "list " ++ testPath "left", "list " ++ testPath "right"]
      stStatus done `shouldBe` CommandFinished 7
      stMode done `shouldBe` Browse

    it "rejects empty and NUL commands before requesting an effect" $ do
      mapM_ (\command -> do
        let ((done, _), calls) = run memory (KeyPress KEnter []) (initial { stMode = Prompt Command command })
        stStatus done `shouldBe` InvalidCommand
        calls `shouldBe` []) ["", " \t ", "echo\0bad"]

    it "shows launch errors without losing the command input or refreshing" $ do
      let ports = memoryProcesses { runCommand = \_ _ -> pure (Left Missing), editFile = \_ _ _ -> pure (Left PermissionDenied) }
          state = initial { stMode = Prompt Command "command" }
          ((failed, _), calls) = runWith memory ports (KeyPress KEnter []) state
          ((editorFailed, _), editCalls) = runWith memory ports (KeyPress (KChar 'e') []) initial
      stMode failed `shouldBe` stMode state
      stStatus failed `shouldBe` Failed Missing
      stStatus editorFailed `shouldBe` Failed PermissionDenied
      calls `shouldBe` []
      editCalls `shouldBe` []

  describe "Use cases with memory ports" $ do
    it "toggles language in every mode without file or process requests" $ do
      mapM_ (\mode -> do
        let st = initial { stMode = mode, stPendingCtrlX = True, stInputCursor = 2 }
            ((updated, quit), calls) = run memory (KeyPress (KFun 2) []) st
        stLanguage updated `shouldBe` English
        stMode updated `shouldBe` mode
        stPendingCtrlX updated `shouldBe` True
        stInputCursor updated `shouldBe` 2
        calls `shouldBe` []
        quit `shouldBe` False)
        [Browse, Search, Prompt Copy "한글", Prompt Move "target", Prompt Mkdir "folder", EditorPrompt "nvim", ConfirmDelete, ViewFile "path" "text" 0]

    it "resolves and copies only after confirmation, then refreshes both panels" $ do
      let ((prompt, _), before) = run memory (KeyPress (KChar 'C') []) initial
          ((done, _), after) = run memory (KeyPress KEnter []) prompt
      before `shouldBe` []
      stMode prompt `shouldBe` Prompt Copy (T.pack (testPath "right"))
      after `shouldBe` ["is-dir " ++ testPath "right", "copy " ++ testPath ("left" </> "file.txt") ++ " " ++ testPath ("right" </> "file.txt"), "list " ++ testPath "left", "list " ++ testPath "right"]
      stMode done `shouldBe` Browse
      stStatus done `shouldBe` Copied

    it "preserves the prompt and skips refresh on an operation failure" $ do
      let ports = memory { copyEntry = \_ _ -> pure (Left PermissionDenied) }
          st = initial { stMode = Prompt Copy (T.pack (testPath "right")) }
          ((done, _), calls) = run ports (KeyPress KEnter []) st
      calls `shouldBe` ["is-dir " ++ testPath "right"]
      stMode done `shouldBe` stMode st
      stStatus done `shouldBe` Failed PermissionDenied

    it "rejects invalid mkdir paths without effects" $ do
      mapM_ (\path -> do
        let ((done, _), calls) = run memory (KeyPress KEnter []) (initial { stMode = Prompt Mkdir path })
        calls `shouldBe` []
        stStatus done `shouldBe` InvalidDestination) ["", ".", "..", T.pack (testPath "absolute"), "nested/folder"]

    it "requires explicit deletion confirmation and supports cancellation" $ do
      let ((pending, _), calls) = run memory (KeyPress (KChar 'D') []) initial
          ((cancelled, _), cancelCalls) = run memory (KeyPress (KChar 'n') []) pending
          ((deleted, _), deleteCalls) = run memory (KeyPress (KChar 'y') []) pending
      stMode pending `shouldBe` ConfirmDelete
      calls `shouldBe` []
      cancelCalls `shouldBe` []
      stMode cancelled `shouldBe` Browse
      deleteCalls `shouldBe` ["delete " ++ testPath ("left" </> "file.txt"), "list " ++ testPath "left", "list " ++ testPath "right"]
      stMode deleted `shouldBe` Browse

    it "preserves both panels if refreshing the second panel fails" $ do
      let ports = memory { readEntries = \_ path -> if path == testPath "right" then pure (Left Missing) else pure (Right []) }
          ((done, _), _) = run ports (KeyPress (KChar 'g') []) initial
      panelEntries (stLeft done) `shouldBe` panelEntries (stLeft initial)
      panelEntries (stRight done) `shouldBe` panelEntries (stRight initial)
      stStatus done `shouldBe` Failed Missing

    it "filters search text without filesystem access" $ do
      let ((updated, _), calls) = run memory (KeyPress (KChar 'z') []) (initial { stMode = Search })
      panelSearch (activePanel updated) `shouldBe` "z"
      selectedElement (panelEntries (activePanel updated)) `shouldBe` Nothing
      calls `shouldBe` []

    it "rejects binary previews while keeping browse state" $ do
      let ports = memory { readPreview = \_ -> pure (Right "text\0binary") }
          ((done, _), _) = run ports (KeyPress (KChar 'v') []) initial
      stMode done `shouldBe` Browse
      stStatus done `shouldBe` BinaryPreviewUnsupported

    it "honors the quit prefix from every mode" $ do
      mapM_ (\mode -> do
        let ((pending, _), _) = run memory (KeyPress (KChar 'x') [MCtrl]) (initial { stMode = mode })
            ((_, quit), calls) = run memory (KeyPress (KChar 'c') [MCtrl]) pending
        quit `shouldBe` True
        calls `shouldBe` []) [Browse, Search, Prompt Mkdir "x", EditorPrompt "nvim", ConfirmDelete, ViewFile "p" "t" 0]

  describe "Theme picker without file or process requests" $ do
    it "offers all eight themes and commits only when Enter is pressed" $ do
      mapM_ (\theme -> do
        let ((opened, _), openCalls) = run memory (KeyPress (KFun 3) []) initial
            ((preview, _), previewCalls) = run memory (KeyPress (KChar (toEnum (fromEnum '1' + fromEnum theme))) []) opened
            ((applied, _), applyCalls) = run memory (KeyPress KEnter []) preview
        fmap (Vec.toList . selectionItems) (stThemePicker opened) `shouldBe` Just themes
        stTheme preview `shouldBe` Dark
        fmap snd (stThemePicker preview >>= selectedElement) `shouldBe` Just theme
        stTheme applied `shouldBe` theme
        stThemePicker applied `shouldBe` Nothing
        openCalls ++ previewCalls ++ applyCalls `shouldBe` []) themes

    it "cancels preview with Esc, C-g, or F3 while preserving the active operation" $ do
      mapM_ (\key -> do
        let st = initial { stMode = Prompt Copy "한글/대상", stInputCursor = 3 }
            ((opened, _), _) = run memory (KeyPress (KFun 3) []) st
            ((preview, _), _) = run memory (KeyPress (KChar '3') []) opened
            ((cancelled, _), calls) = run memory key preview
        stTheme cancelled `shouldBe` Dark
        stThemePicker cancelled `shouldBe` Nothing
        stMode cancelled `shouldBe` stMode st
        stInputCursor cancelled `shouldBe` 3
        selectedEntry cancelled `shouldBe` selectedEntry st
        calls `shouldBe` []) [KeyPress KEsc [], KeyPress (KChar 'g') [MCtrl], KeyPress (KFun 3) []]

    it "preserves every mode, its input and selected files when applying a theme" $ do
      mapM_ (\mode -> do
        let st = initial { stMode = mode, stInputCursor = 2 }
            ((opened, _), _) = run memory (KeyPress (KFun 3) []) st
            ((preview, _), _) = run memory (KeyPress KEnd []) opened
            ((done, _), calls) = run memory (KeyPress KEnter []) preview
        stTheme done `shouldBe` GruvboxLight
        stMode done `shouldBe` mode
        stInputCursor done `shouldBe` 2
        panelEntries (stLeft done) `shouldBe` panelEntries (stLeft st)
        panelSearch (activePanel done) `shouldBe` panelSearch (activePanel st)
        calls `shouldBe` []) [Browse, Search, Prompt Copy "a", Prompt Move "b", Prompt Mkdir "c", EditorPrompt "nvim", ConfirmDelete, ViewFile "p" "text" 1]

    it "keeps theme navigation within the eight choices and supports Emacs keys" $ do
      let ((opened, _), _) = run memory (KeyPress (KFun 3) []) initial
          ((first, _), _) = run memory (KeyPress KHome []) opened
          ((clamped, _), _) = run memory (KeyPress (KChar 'p') [MCtrl]) first
          ((next, _), _) = run memory (KeyPress (KChar 'n') [MCtrl]) clamped
          ((lastChoice, _), _) = run memory (KeyPress KEnd []) opened
          ((clampedLast, _), _) = run memory (KeyPress (KChar 'n') [MCtrl]) lastChoice
      fmap snd (stThemePicker clamped >>= selectedElement) `shouldBe` Just Light
      fmap snd (stThemePicker next >>= selectedElement) `shouldBe` Just Dark
      fmap snd (stThemePicker clampedLast >>= selectedElement) `shouldBe` Just GruvboxLight

    it "allows language changes and the global quit prefix inside the picker" $ do
      let ((opened, _), _) = run memory (KeyPress (KFun 3) []) initial
          ((english, _), _) = run memory (KeyPress (KFun 2) []) opened
          ((prefix, _), _) = run memory (KeyPress (KChar 'x') [MCtrl]) english
          ((_, quit), calls) = run memory (KeyPress (KChar 'c') [MCtrl]) prefix
      stLanguage english `shouldBe` English
      stThemePicker english `shouldBe` stThemePicker opened
      quit `shouldBe` True
      calls `shouldBe` []

  describe "Panel state" $ do
    it "검색에서 부모 항목을 유지하고 선택을 복원한다" $ do
      let entries = [Entry ".." Parent 0, Entry "alpha" RegularFile 1, Entry "beta" RegularFile 1]
          st = initialState "/tmp" entries "/tmp" entries defaultConfig (80, 24)
          panel = stLeft st
          filtered = refreshPanel entries (Just "beta") (panel { panelSearch = "BETA" })
      map entryName (Vec.toList (selectionItems (panelEntries filtered))) `shouldBe` ["..", "beta"]
      fmap (entryName . snd) (selectedElement (panelEntries filtered)) `shouldBe` Just "beta"

  describe "Pure plans and response-dependent workflows" $ do
    it "finishes a search edit without even needing a port implementation" $ do
      case planInput (KeyPress (KChar 'z') []) (initial { stMode = Search }) of
        Done (state, quit) -> do
          panelSearch (activePanel state) `shouldBe` "z"
          quit `shouldBe` False
        Await _ _ -> expectationFailure "Search requested a filesystem effect"

    it "uses the directory response to choose a transfer target and stops on failure" $ do
      let state = initial { stMode = Prompt Copy (T.pack (testPath "right")) }
      case planInput (KeyPress KEnter []) state of
        Await (DirectoryExists path) resume -> do
          path `shouldBe` testPath "right"
          case resume (Right True) of
            Await (CopyEntry source target) copied -> do
              source `shouldBe` testPath ("left" </> "file.txt")
              target `shouldBe` testPath ("right" </> "file.txt")
              case copied (Left PermissionDenied) of
                Done (failed, quit) -> do
                  stStatus failed `shouldBe` Failed PermissionDenied
                  stMode failed `shouldBe` stMode state
                  quit `shouldBe` False
                _ -> expectationFailure "Failed transfer requested another effect"
            _ -> expectationFailure "Expected a copy after resolving the directory"
          case resume (Right False) of
            Await (CopyEntry _ target) _ -> target `shouldBe` testPath "right"
            _ -> expectationFailure "Expected a copy to the requested new filename"
        _ -> expectationFailure "Expected destination inspection before a transfer"

    it "does not mutate or refresh when destination inspection fails" $ do
      let ports = memory { doesDirectoryExist = \_ -> recordFailure }
          recordFailure = modify (++ ["inspect failed"]) >> pure (Left PermissionDenied)
          state = initial { stMode = Prompt Move (T.pack (testPath "right")) }
          ((done, _), calls) = run ports (KeyPress KEnter []) state
      calls `shouldBe` ["inspect failed"]
      stMode done `shouldBe` stMode state
      stStatus done `shouldBe` Failed PermissionDenied

    it "initializes through ports and uses canonical paths for listing" $ do
      let ports = memory { canonicalizePath = \path -> record ("resolve " ++ path) (testPath path) }
          (result, calls) = runState (runProgram ports memoryProcesses (planStartup "left" "right" defaultConfig (80, 24))) []
      calls `shouldBe` ["resolve left", "resolve right", "list " ++ testPath "left", "list " ++ testPath "right"]
      case result of
        Right state -> do
          panelPath (stLeft state) `shouldBe` testPath "left"
          panelPath (stRight state) `shouldBe` testPath "right"
          stStatus state `shouldBe` Ready
        Left err -> expectationFailure (show err)

    it "short-circuits startup without listing when path resolution fails" $ do
      let ports = memory { canonicalizePath = \path -> modify (++ ["resolve " ++ path]) >> pure (Left Missing) }
          (result, calls) = runState (runProgram ports memoryProcesses (planStartup "left" "right" defaultConfig (80, 24))) []
      calls `shouldBe` ["resolve left"]
      case result of
        Left err -> err `shouldBe` Missing
        Right _ -> expectationFailure "Startup succeeded after resolution failure"
