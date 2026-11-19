{-# LANGUAGE GADTs #-}

module MachineSpec (spec) where

import           Hfm.Application.Error
import           Hfm.Application.Machine  (resume)
import           Hfm.Application.Program
import           Hfm.Application.Startup  (planStartup)
import           Hfm.Application.State
import           Hfm.Application.Status
import           Hfm.Application.Workflow (planInput)
import           Hfm.Domain.Config        (Settings (..))
import           Hfm.Domain.Entry
import           Hfm.Domain.Input
import           Hfm.Domain.Selection
import           Hfm.Domain.Theme         (themes)

import           System.FilePath          ((</>))

import           Test.Hspec

initial :: AppState
initial = initialState "left" [Entry "file.txt" RegularFile 4] "right" [] defaultConfig (80, 24)

enter :: Input
enter = KeyPress KEnter []

expectState :: Program (AppState, Lifecycle) -> (AppState -> Expectation) -> Expectation
expectState (Done (state, lifecycle)) check = do
  lifecycle `shouldBe` Continue
  check state
expectState (Await _ _) _ = expectationFailure "Unexpected additional effect"

expectFailure :: AppState -> Program (AppState, Lifecycle) -> Expectation
expectFailure original program = expectState program $ \state -> do
  stStatus state `shouldBe` Failed PermissionDenied
  stMode state `shouldBe` stMode original
  panelEntries (stLeft state) `shouldBe` panelEntries (stLeft original)
  panelEntries (stRight state) `shouldBe` panelEntries (stRight original)

expectStartupFailure :: Phase response (Either FileError AppState) -> Expectation
expectStartupFailure phase = case resume phase (Left PermissionDenied) of
  Done (Left err) -> err `shouldBe` PermissionDenied
  _ -> expectationFailure "Startup continued after a failed request"

checkFailedRefresh :: AppState -> Expectation
checkFailedRefresh state = do
  stMode state `shouldBe` Browse
  stStatus state `shouldBe` Failed PermissionDenied
  panelAll (stLeft state) `shouldBe` panelAll (stLeft initial)
  panelAll (stRight state) `shouldBe` panelAll (stRight initial)

spec :: Spec
spec = do
  describe "Explicit startup transitions" $ do
    it "can pause at every stage and stops at any failed response" $ do
      case planStartup "left-arg" "right-arg" defaultConfig (90, 30) of
        Await (CanonicalizePath leftArg) leftPhase -> do
          leftArg `shouldBe` "left-arg"
          expectStartupFailure leftPhase
          case resume leftPhase (Right "resolved-left") of
            Await (CanonicalizePath rightArg) rightPhase -> do
              rightArg `shouldBe` "right-arg"
              expectStartupFailure rightPhase
              case resume rightPhase (Right "resolved-right") of
                Await (ReadEntries hidden left) leftEntriesPhase -> do
                  (hidden, left) `shouldBe` (False, "resolved-left")
                  expectStartupFailure leftEntriesPhase
                  case resume leftEntriesPhase (Right [Entry "first" RegularFile 1]) of
                    Await (ReadEntries rightHidden right) rightEntriesPhase -> do
                      (rightHidden, right) `shouldBe` (False, "resolved-right")
                      expectStartupFailure rightEntriesPhase
                      case resume rightEntriesPhase (Right [Entry "second" Directory 0]) of
                        Done (Right state) -> do
                          panelPath (stLeft state) `shouldBe` "resolved-left"
                          panelPath (stRight state) `shouldBe` "resolved-right"
                          map entryName (panelAll (stLeft state)) `shouldBe` ["first"]
                          map entryName (panelAll (stRight state)) `shouldBe` ["second"]
                          stTerminalSize state `shouldBe` (90, 30)
                        _ -> expectationFailure "Startup did not finish after both lists"
                    _ -> expectationFailure "Expected the right directory listing"
                _ -> expectationFailure "Expected the left directory listing"
            _ -> expectationFailure "Expected right path resolution"
        _ -> expectationFailure "Expected left path resolution"

  describe "Settings transactions without ports" $ do
    it "commits a language change only on a successful save response" $ do
      case planInput (KeyPress (KFun 2) []) initial of
        Await (SaveSettings settings) phase -> do
          settingsLanguage settings `shouldBe` English
          stLanguage initial `shouldBe` Korean
          expectState (resume phase (Right ())) $ \state ->
            stLanguage state `shouldBe` English
          expectState (resume phase (Left PermissionDenied)) $ \state -> do
            currentSettings state `shouldBe` currentSettings initial
            stStatus state `shouldBe` SettingsSaveFailed PermissionDenied
        _ -> expectationFailure "Expected an explicit settings request"

    it "restores the editor prompt and cursor when saving the same editor fails" $ do
      let state = initial { stMode = EditorPrompt "", stInputCursor = 0 }
      case planInput enter state of
        Await (SaveSettings settings) phase -> do
          settings `shouldBe` currentSettings initial
          expectState (resume phase (Left PermissionDenied)) $ \failed -> do
            stMode failed `shouldBe` EditorPrompt ""
            stInputCursor failed `shouldBe` 0
            stStatus failed `shouldBe` SettingsSaveFailed PermissionDenied
        _ -> expectationFailure "Explicit editor confirmation must save unchanged settings"

    it "preserves an underlying prompt and preview when theme persistence fails" $ do
      let state = initial { stMode = Prompt Copy "destination", stInputCursor = 5
                          , stThemePicker = Just (selectAt 2 (selection themes)) }
      case planInput enter state of
        Await (SaveSettings settings) phase -> do
          settingsTheme settings `shouldBe` Monokai
          expectState (resume phase (Left PermissionDenied)) $ \failed -> do
            currentSettings failed `shouldBe` currentSettings state
            stMode failed `shouldBe` stMode state
            stInputCursor failed `shouldBe` 5
            stThemePicker failed `shouldBe` stThemePicker state
          expectState (resume phase (Right ())) $ \saved -> do
            stTheme saved `shouldBe` Monokai
            stThemePicker saved `shouldBe` Nothing
            stMode saved `shouldBe` stMode state
        _ -> expectationFailure "Expected committed theme persistence"

    it "closes an unchanged theme without requesting persistence" $ do
      let state = initial { stThemePicker = Just (selectAt (fromEnum (stTheme initial)) (selection themes)) }
      expectState (planInput enter state) $ \closed ->
        stThemePicker closed `shouldBe` Nothing

  describe "Navigation and preview response branches" $ do
    it "commits a new directory only after its canonical listing succeeds" $ do
      let original = initial { stActive = RightSide
                             , stRight = Panel "right" (selection [Entry "folder" Directory 0]) [] "filter" }
      case planInput enter original of
        Await (CanonicalizePath path) phase -> do
          path `shouldBe` "right" </> "folder"
          expectFailure original (resume phase (Left PermissionDenied))
          case resume phase (Right "canonical-folder") of
            Await (ReadEntries _ canonical) listed -> do
              canonical `shouldBe` "canonical-folder"
              expectFailure original (resume listed (Left PermissionDenied))
              expectState (resume listed (Right [])) $ \state -> do
                panelPath (stRight state) `shouldBe` "canonical-folder"
                panelSearch (stRight state) `shouldBe` ""
                panelEntries (stLeft state) `shouldBe` panelEntries (stLeft original)
                stStatus state `shouldBe` CurrentDirectory "canonical-folder"
            _ -> expectationFailure "Expected canonical directory listing"
        _ -> expectationFailure "Expected path resolution before navigation"

    it "uses a symbolic link inspection response to choose navigation or preview" $ do
      let state = initialState "left" [Entry "link" SymbolicLink 0] "right" [] defaultConfig (80, 24)
          path = "left" </> "link"
      case planInput enter state of
        Await (DirectoryExists actual) phase -> do
          actual `shouldBe` path
          expectFailure state (resume phase (Left PermissionDenied))
          case resume phase (Right True) of
            Await (CanonicalizePath destination) _ -> destination `shouldBe` path
            _ -> expectationFailure "Directory link did not request navigation"
          case resume phase (Right False) of
            Await (ReadPreview preview) previewed -> do
              preview `shouldBe` path
              expectFailure state (resume previewed (Left PermissionDenied))
              expectState (resume previewed (Right "contents")) $ \viewed ->
                stMode viewed `shouldBe` ViewFile path "contents" 0
            _ -> expectationFailure "File link did not request preview"
        _ -> expectationFailure "Expected symbolic link inspection"

    it "rejects binary preview responses and decodes invalid UTF-8 safely" $ do
      case planInput enter initial of
        Await (ReadPreview path) phase -> do
          expectState (resume phase (Right "text\0data")) $ \state -> do
            stMode state `shouldBe` Browse
            stStatus state `shouldBe` BinaryPreviewUnsupported
          expectState (resume phase (Right "\xff")) $ \state ->
            stMode state `shouldBe` ViewFile path "\xfffd" 0
        _ -> expectationFailure "Expected a file preview request"

  describe "File mutation and refresh boundaries" $ do
    it "retains inputs and stops after any first mutation or process failure" $ do
      let cases = [(enter, initial { stMode = Prompt Rename "new" }),
                   (enter, initial { stMode = Prompt Mkdir "new" }),
                   (enter, initial { stMode = Prompt Command "exit 0" }),
                   (KeyPress (KChar 'y') [], initial { stMode = ConfirmDelete }),
                   (KeyPress (KChar 'e') [], initial)]
      mapM_ (\(input, state) -> case planInput input state of
        Await _ phase -> expectFailure state (resume phase (Left PermissionDenied))
        _ -> expectationFailure "Expected an operation request") cases

    it "resolves move destinations before moving and preserves the prompt on failure" $ do
      let state = initial { stMode = Prompt Move "right" }
      case planInput enter state of
        Await (DirectoryExists requested) phase -> do
          requested `shouldBe` "left" </> "right"
          expectFailure state (resume phase (Left PermissionDenied))
          case resume phase (Right False) of
            Await (MoveEntry source destination) moved -> do
              source `shouldBe` "left" </> "file.txt"
              destination `shouldBe` requested
              expectFailure state (resume moved (Left PermissionDenied))
            _ -> expectationFailure "Expected resolved move request"
        _ -> expectationFailure "Expected destination inspection"

    it "does not repeat a completed mutation when either refresh request fails" $ do
      let state = initial { stMode = Prompt Mkdir "new" }
      case planInput enter state of
        Await (MakeDirectory path) created -> do
          path `shouldBe` "left" </> "new"
          case resume created (Right ()) of
            Await (ReadEntries _ left) refreshedLeft -> do
              left `shouldBe` "left"
              expectState (resume refreshedLeft (Left PermissionDenied)) checkFailedRefresh
              case resume refreshedLeft (Right []) of
                Await (ReadEntries _ right) refreshedRight -> do
                  right `shouldBe` "right"
                  expectState (resume refreshedRight (Left PermissionDenied)) checkFailedRefresh
                  expectState (resume refreshedRight (Right [])) $ \done -> do
                    panelAll (stLeft done) `shouldBe` []
                    panelAll (stRight done) `shouldBe` []
                    stStatus done `shouldBe` DirectoryCreated
                _ -> expectationFailure "Expected second refresh before committing either panel"
            _ -> expectationFailure "Expected refresh after successful mutation"
        _ -> expectationFailure "Expected directory creation"

  describe "Key sequence lifecycle" $ do
    it "preserves pending prefixes across resize and language transactions" $ do
      let state = initial { stKeySequence = ControlXPrefix }
      expectState (planInput (Resize 30 10) state) $ \resized -> do
        stKeySequence resized `shouldBe` ControlXPrefix
        stTerminalSize resized `shouldBe` (30, 10)
      case planInput (KeyPress (KFun 2) []) state of
        Await (SaveSettings _) phase -> expectState (resume phase (Right ())) $ \saved ->
          stKeySequence saved `shouldBe` ControlXPrefix
        _ -> expectationFailure "Expected language persistence"

    it "consumes cancelled or unknown prefixes without losing a prompt" $ do
      let state = initial { stMode = Prompt Copy "target", stKeySequence = ControlXPrefix }
      mapM_ (\key -> expectState (planInput key state) $ \updated -> do
        stKeySequence updated `shouldBe` DirectInput
        stMode updated `shouldBe` stMode state)
        [KeyPress KEsc [], KeyPress (KChar 'g') [MCtrl], KeyPress (KChar '?') []]

    it "rejects F4 inside an active operation or theme picker" $ do
      let states = [initial { stMode = Prompt Copy "target" },
                    initial { stThemePicker = Just (selection themes) }]
      mapM_ (\state -> expectState (planInput (KeyPress (KFun 4) []) state) $ \updated -> do
        stMode updated `shouldBe` stMode state
        stThemePicker updated `shouldBe` stThemePicker state) states
