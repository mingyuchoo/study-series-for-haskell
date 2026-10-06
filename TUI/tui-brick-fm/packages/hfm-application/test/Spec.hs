module Main (main) where

import Control.Monad.State.Strict (State, modify, runState)
import Hfm.Application.Ports
import Hfm.Application.State
import Hfm.Application.UseCases
import Hfm.Domain.Entry
import Hfm.Domain.Input
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
  , doesDirectoryExist = \path -> record ("is-dir " ++ path) False
  , readPreview = \path -> record ("preview " ++ path) "text"
  , copyEntry = \source target -> record ("copy " ++ source ++ " " ++ target) ()
  , moveEntry = \source target -> record ("move " ++ source ++ " " ++ target) ()
  , deleteEntry = \path -> record ("delete " ++ path) ()
  , makeDirectory = \path -> record ("mkdir " ++ path) ()
  , destinationFor = \_ source _ -> record ("destination " ++ source) "/right/file.txt"
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
      after `shouldBe` ["destination /left/file.txt", "copy /left/file.txt /right/file.txt", "list /left", "list /right"]
      stMode done `shouldBe` Browse
      stStatus done `shouldBe` "복사했습니다"

    it "preserves the prompt and skips refresh on an operation failure" $ do
      let ports = memory { copyEntry = \_ _ -> pure (Left PermissionDenied) }
          st = initial { stMode = Prompt Copy "/right" }
          ((done, _), calls) = run ports (KeyPress KEnter []) st
      calls `shouldBe` ["destination /left/file.txt"]
      stMode done `shouldBe` stMode st
      stStatus done `shouldBe` "오류: 파일 접근 권한이 없습니다"

    it "rejects invalid mkdir paths without effects" $ do
      mapM_ (\path -> do
        let ((done, _), calls) = run memory (KeyPress KEnter []) (initial { stMode = Prompt Mkdir path })
        calls `shouldBe` []
        stStatus done `shouldBe` "유효한 대상 경로를 입력하세요") ["", ".", "..", "/absolute", "nested/folder"]

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
      stStatus done `shouldBe` "오류: 파일이 존재하지 않습니다"

    it "filters search text without filesystem access" $ do
      let ((updated, _), calls) = run memory (KeyPress (KChar 'z') []) (initial { stMode = Search })
      panelSearch (activePanel updated) `shouldBe` "z"
      selectedElement (panelEntries (activePanel updated)) `shouldBe` Nothing
      calls `shouldBe` []

    it "rejects binary previews while keeping browse state" $ do
      let ports = memory { readPreview = \_ -> pure (Right "text\0binary") }
          ((done, _), _) = run ports (KeyPress (KChar 'v') []) initial
      stMode done `shouldBe` Browse
      stStatus done `shouldBe` "바이너리 파일은 미리 볼 수 없습니다"

    it "honors the quit prefix from every mode" $ do
      mapM_ (\mode -> do
        let ((pending, _), _) = run memory (KeyPress (KChar 'x') [MCtrl]) (initial { stMode = mode })
            ((_, quit), calls) = run memory (KeyPress (KChar 'c') [MCtrl]) pending
        quit `shouldBe` True
        calls `shouldBe` []) [Browse, Search, Prompt Mkdir "x", ConfirmDelete, ViewFile "p" "t" 0]
