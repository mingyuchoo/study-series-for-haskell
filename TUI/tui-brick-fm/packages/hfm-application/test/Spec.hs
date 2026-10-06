{-# LANGUAGE GADTs #-}

module Main (main) where

import Control.Monad.State.Strict (State, modify, runState)
import Hfm.Application.Ports
import Hfm.Application.State
import Hfm.Application.Program
import Hfm.Application.Startup (planStartup)
import Hfm.Application.Workflow (planInput)
import Hfm.Application.Status
import Hfm.Application.UseCases
import qualified Data.Vector as Vec
import Hfm.Domain.Entry
import Hfm.Domain.Input
import Hfm.Domain.Theme (themes)
import Hfm.Domain.Selection
import Test.Hspec hiding (before, after, pending)

main :: IO ()
main = hspec spec

entry :: Entry
entry = Entry "file.txt" RegularFile 4

initial :: AppState
initial = initialState "/left" [entry] "/right" [] defaultConfig (80, 24)

record :: String -> a -> State [String] (Either FileError a)
record call result = modify (++ [call]) >> pure (Right result)

-- Deterministic memory ports; these tests have no IO or terminal dependency.
memory :: FileSystem (State [String])
memory = FileSystem
  { readEntries = \_ path -> record ("list " ++ path) [entry]
  , canonicalizePath = \path -> record ("resolve " ++ path) path
  , doesDirectoryExist = \path -> record ("is-dir " ++ path) (path == "/right")
  , readPreview = \path -> record ("preview " ++ path) "text"
  , copyEntry = \source target -> record ("copy " ++ source ++ " " ++ target) ()
  , moveEntry = \source target -> record ("move " ++ source ++ " " ++ target) ()
  , deleteEntry = \path -> record ("delete " ++ path) ()
  , makeDirectory = \path -> record ("mkdir " ++ path) ()
  }

run :: FileSystem (State [String]) -> Input -> AppState -> ((AppState, Bool), [String])
run ports input state = runState (handleInput ports input state) []

spec :: Spec
spec = do
  describe "Use cases with memory ports" $ do
    it "toggles language in every mode without effects" $ do
      mapM_ (\mode -> do
        let st = initial { stMode = mode, stPendingCtrlX = True, stInputCursor = 2 }
            ((updated, quit), calls) = run memory (KeyPress (KFun 2) []) st
        stLanguage updated `shouldBe` English
        stMode updated `shouldBe` mode
        stPendingCtrlX updated `shouldBe` True
        stInputCursor updated `shouldBe` 2
        calls `shouldBe` []
        quit `shouldBe` False)
        [Browse, Search, Prompt Copy "한글", Prompt Move "target", Prompt Mkdir "folder", ConfirmDelete, ViewFile "path" "text" 0]

    it "resolves and copies only after confirmation, then refreshes both panels" $ do
      let ((prompt, _), before) = run memory (KeyPress (KChar 'C') []) initial
          ((done, _), after) = run memory (KeyPress KEnter []) prompt
      before `shouldBe` []
      stMode prompt `shouldBe` Prompt Copy "/right"
      after `shouldBe` ["is-dir /right", "copy /left/file.txt /right/file.txt", "list /left", "list /right"]
      stMode done `shouldBe` Browse
      stStatus done `shouldBe` Copied

    it "preserves the prompt and skips refresh on an operation failure" $ do
      let ports = memory { copyEntry = \_ _ -> pure (Left PermissionDenied) }
          st = initial { stMode = Prompt Copy "/right" }
          ((done, _), calls) = run ports (KeyPress KEnter []) st
      calls `shouldBe` ["is-dir /right"]
      stMode done `shouldBe` stMode st
      stStatus done `shouldBe` Failed PermissionDenied

    it "rejects invalid mkdir paths without effects" $ do
      mapM_ (\path -> do
        let ((done, _), calls) = run memory (KeyPress KEnter []) (initial { stMode = Prompt Mkdir path })
        calls `shouldBe` []
        stStatus done `shouldBe` InvalidDestination) ["", ".", "..", "/absolute", "nested/folder"]

    it "requires explicit deletion confirmation and supports cancellation" $ do
      let ((pending, _), calls) = run memory (KeyPress (KChar 'D') []) initial
          ((cancelled, _), cancelCalls) = run memory (KeyPress (KChar 'n') []) pending
          ((deleted, _), deleteCalls) = run memory (KeyPress (KChar 'y') []) pending
      stMode pending `shouldBe` ConfirmDelete
      calls `shouldBe` []
      cancelCalls `shouldBe` []
      stMode cancelled `shouldBe` Browse
      deleteCalls `shouldBe` ["delete /left/file.txt", "list /left", "list /right"]
      stMode deleted `shouldBe` Browse

    it "preserves both panels if refreshing the second panel fails" $ do
      let ports = memory { readEntries = \_ path -> if path == "/right" then pure (Left Missing) else pure (Right []) }
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
        calls `shouldBe` []) [Browse, Search, Prompt Mkdir "x", ConfirmDelete, ViewFile "p" "t" 0]

  describe "Theme picker without effects" $ do
    it "offers all six themes and commits only when Enter is pressed" $ do
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
        stTheme done `shouldBe` TomorrowNightBlue
        stMode done `shouldBe` mode
        stInputCursor done `shouldBe` 2
        panelEntries (stLeft done) `shouldBe` panelEntries (stLeft st)
        panelSearch (activePanel done) `shouldBe` panelSearch (activePanel st)
        calls `shouldBe` []) [Browse, Search, Prompt Copy "a", Prompt Move "b", Prompt Mkdir "c", ConfirmDelete, ViewFile "p" "text" 1]

    it "keeps theme navigation within the six choices and supports Emacs keys" $ do
      let ((opened, _), _) = run memory (KeyPress (KFun 3) []) initial
          ((first, _), _) = run memory (KeyPress KHome []) opened
          ((clamped, _), _) = run memory (KeyPress (KChar 'p') [MCtrl]) first
          ((next, _), _) = run memory (KeyPress (KChar 'n') [MCtrl]) clamped
      fmap snd (stThemePicker clamped >>= selectedElement) `shouldBe` Just Light
      fmap snd (stThemePicker next >>= selectedElement) `shouldBe` Just Dark

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
      let state = initial { stMode = Prompt Copy "/right" }
      case planInput (KeyPress KEnter []) state of
        Await (DirectoryExists path) resume -> do
          path `shouldBe` "/right"
          case resume (Right True) of
            Await (CopyEntry source target) copied -> do
              source `shouldBe` "/left/file.txt"
              target `shouldBe` "/right/file.txt"
              case copied (Left PermissionDenied) of
                Done (failed, quit) -> do
                  stStatus failed `shouldBe` Failed PermissionDenied
                  stMode failed `shouldBe` stMode state
                  quit `shouldBe` False
                _ -> expectationFailure "Failed transfer requested another effect"
            _ -> expectationFailure "Expected a copy after resolving the directory"
          case resume (Right False) of
            Await (CopyEntry _ target) _ -> target `shouldBe` "/right"
            _ -> expectationFailure "Expected a copy to the requested new filename"
        _ -> expectationFailure "Expected destination inspection before a transfer"

    it "does not mutate or refresh when destination inspection fails" $ do
      let ports = memory { doesDirectoryExist = \_ -> recordFailure }
          recordFailure = modify (++ ["inspect failed"]) >> pure (Left PermissionDenied)
          state = initial { stMode = Prompt Move "/right" }
          ((done, _), calls) = run ports (KeyPress KEnter []) state
      calls `shouldBe` ["inspect failed"]
      stMode done `shouldBe` stMode state
      stStatus done `shouldBe` Failed PermissionDenied

    it "initializes through ports and uses canonical paths for listing" $ do
      let ports = memory { canonicalizePath = \path -> record ("resolve " ++ path) ("/" ++ path) }
          (result, calls) = runState (runProgram ports (planStartup "left" "right" defaultConfig (80, 24))) []
      calls `shouldBe` ["resolve left", "resolve right", "list /left", "list /right"]
      case result of
        Right state -> do
          panelPath (stLeft state) `shouldBe` "/left"
          panelPath (stRight state) `shouldBe` "/right"
          stStatus state `shouldBe` Ready
        Left err -> expectationFailure (show err)

    it "short-circuits startup without listing when path resolution fails" $ do
      let ports = memory { canonicalizePath = \path -> modify (++ ["resolve " ++ path]) >> pure (Left Missing) }
          (result, calls) = runState (runProgram ports (planStartup "left" "right" defaultConfig (80, 24))) []
      calls `shouldBe` ["resolve left"]
      case result of
        Left err -> err `shouldBe` Missing
        Right _ -> expectationFailure "Startup succeeded after resolution failure"
