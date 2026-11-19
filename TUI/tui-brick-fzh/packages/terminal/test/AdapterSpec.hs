module AdapterSpec
    ( spec
    ) where

import qualified Brick.Widgets.List as List

import           Config

import           Control.Exception  (bracket)

import qualified Data.Text.IO       as TIO

import           Event              (loadFileContent, toSessionEvent)

import           FileSearch         (listFilesWithIssues)

import qualified Fzh.Domain.Search  as Search
import           Fzh.Domain.Session

import qualified Graphics.Vty       as V

import           System.Directory
import           System.FilePath    ((</>))
import           System.IO          (hClose, openTempFile)

import           Test.Hspec

import           Types              (defaultConfig, initialState,
                                     stFilteredList, stSession, transitionApp)

spec :: Spec
spec = do
  describe "terminal state projection" $ do
    it "keeps rendered selection and results consistent through edits and navigation" $ do
      let initial = initialState ["alpha", "beta"] defaultConfig (80, 24)
          (moved, _) = transitionApp (Navigate Search.Next) initial
          (filtered, _) = transitionApp (EditQuery (Append 'z')) moved
          (restored, _) = transitionApp (EditQuery Clear) filtered
      List.listSelectedElement (stFilteredList moved) `shouldBe` Just (1, "beta")
      List.listSelectedElement (stFilteredList filtered) `shouldBe` Nothing
      List.listSelectedElement (stFilteredList restored) `shouldBe` Just (0, "alpha")
      Search.selectedItem (browserSearch (sessionBrowser (stSession restored)))
        `shouldBe` Just "alpha"
  describe "key event adapter" $ do
    it "maps all common events for both styles" $ do
      let bindings =
            [ (V.EvKey V.KEsc [], Dismiss)
            , (V.EvKey V.KEnter [], Confirm)
            , (V.EvKey V.KUp [], Navigate Search.Previous)
            , (V.EvKey V.KDown [], Navigate Search.Next)
            , (V.EvKey (V.KChar 'u') [V.MCtrl], EditQuery Clear)
            , (V.EvKey V.KBS [], EditQuery Delete)
            , (V.EvKey (V.KChar '한') [], EditQuery (Append '한'))
            , (V.EvResize 120 40, TerminalResized 120 40)
            ]
      mapM_
        ( \style ->
            mapM_ (\(event, expected) -> toSessionEvent style event `shouldBe` Just expected) bindings
        )
        [Emacs, Vim]
    it "maps style-specific bindings and ignores unsupported keys" $ do
      let bindings =
            [ (Emacs, 'p', Navigate Search.Previous)
            , (Emacs, 'n', Navigate Search.Next)
            , (Emacs, 'g', Dismiss)
            , (Emacs, 'h', EditQuery Delete)
            , (Vim, 'k', Navigate Search.Previous)
            , (Vim, 'j', Navigate Search.Next)
            , (Vim, 'c', Dismiss)
            , (Vim, 'w', EditQuery Delete)
            ]
      mapM_
        ( \(style, key, expected) -> toSessionEvent style (V.EvKey (V.KChar key) [V.MCtrl]) `shouldBe` Just expected
        )
        bindings
      toSessionEvent Emacs (V.EvKey (V.KChar 'j') [V.MCtrl]) `shouldBe` Nothing
      toSessionEvent Vim (V.EvKey (V.KChar 'p') [V.MCtrl]) `shouldBe` Nothing
      toSessionEvent Vim (V.EvKey V.KEnter [V.MAlt]) `shouldBe` Nothing
  describe "preview adapter" $ do
    it "reads real content and represents a missing file as failure" $ withTestDirectory $ \directory -> do
      let path = directory </> "preview.hs"
      TIO.writeFile path "한글 content"
      loadFileContent path `shouldReturn` Right "한글 content"
      loadFileContent (directory </> "missing") `shouldReturn` Left MissingFile
  describe "configuration adapter" $ do
    it "distinguishes missing, malformed, configured and defaulted YAML" $ withTestDirectory $ \directory -> do
      let path = directory </> "keybindings.yaml"
      loadKeyBindingConfigFrom path `shouldReturn` ConfigMissing
      writeFile path "binding_style: vim\n"
      loadKeyBindingConfigFrom path `shouldReturn` ConfigLoaded (KeyBindingConfig Vim)
      writeFile path "{}"
      loadKeyBindingConfigFrom path `shouldReturn` ConfigLoaded defaultKeyBindingConfig
      writeFile path "binding_style: ["
      result <- loadKeyBindingConfigFrom path
      result `shouldSatisfy` (\value -> case value of ConfigInvalid _ -> True; _ -> False)
  describe "discovery adapter" $ do
    it "reports missing roots instead of silently swallowing failures" $ withTestDirectory $ \directory -> do
      (files, issues) <- listFilesWithIssues (directory </> "missing")
      files `shouldBe` []
      length issues `shouldBe` 1
    it "skips excluded paths and directory symlink cycles while preserving file symlinks" $ withTestDirectory $ \directory -> do
      createDirectory (directory </> "src")
      createDirectory (directory </> ".git")
      writeFile (directory </> "src/a.hs") "a"
      writeFile (directory </> ".git/config") "ignored"
      createDirectoryLink directory (directory </> "src/loop")
      createFileLink (directory </> "src/a.hs") (directory </> "linked.hs")
      (files, issues) <- listFilesWithIssues directory
      files `shouldMatchList` [directory </> "src/a.hs", directory </> "linked.hs"]
      issues `shouldBe` []

withTestDirectory :: (FilePath -> IO a) -> IO a
withTestDirectory = bracket create removeDirectoryRecursive
  where
    create = do
      temporary <- getTemporaryDirectory
      (path, handle) <- openTempFile temporary "fzh-adapter-test"
      hClose handle
      removeFile path
      createDirectory path
      pure path
