module Main (main) where

import           Control.Monad             (forM_)

import           Data.List                 (isInfixOf)

import           Hfm.DevTools.Architecture
import           Hfm.DevTools.Workspace    (readWorkspace)

import           System.Directory          (createDirectoryIfMissing)
import           System.FilePath           (takeDirectory, (</>))
import           System.IO                 (IOMode (WriteMode), hPutStr,
                                            hSetEncoding, utf8, withFile)
import           System.IO.Temp            (withSystemTempDirectory)

import           Test.Hspec

main :: IO ()
main = hspec $ describe "Architecture boundaries" $ do
  it "accepts pure requests and the registered workspace" $
    checkWorkspace (source "import Hfm.Application.Program\nimport Hfm.Application.Error\n") `shouldBe` []
  it "rejects adapter dependencies" $
    checkWorkspace (manifest "hfm-application" "dependencies:\n- base\n- hfm-infrastructure\n") `shouldSatisfy` has "forbidden dependency"
  it "rejects multiline framework imports" $
    checkWorkspace (source "import\n qualified Graphics.Vty as V\n") `shouldSatisfy` has "effect/framework module"
  it "rejects execution ports and interpreters in pure plans" $
    forM_ ["Hfm.Application.Effects.Ports (FileSystem)", "qualified Hfm.Application.Effects.Ports as P", "Hfm.Application.Effects.Ports (Processes)", "Hfm.Application.Effects.Runtime"] $ \imported ->
      checkWorkspace (source ("import " ++ imported)) `shouldSatisfy` has "instead of describing requests"
  it "allows only the full effect module paths to execute ports" $ do
    checkWorkspace (fixture ++ [("packages/hfm-application/src/Hfm/Application/Effects/Runtime.hs", "import Hfm.Application.Effects.Ports\n")]) `shouldBe` []
    checkWorkspace (fixture ++ [("packages/hfm-application/src/Runtime.hs", "import Hfm.Application.Effects.Ports\n")]) `shouldSatisfy` has "executable ports"
  it "checks conditional and library dependencies" $
    forM_ ["when:\n- condition: os(windows)\n  dependencies:\n  - process\n", "library:\n  dependencies:\n  - directory\n"] $ \section ->
      checkWorkspace (manifest "hfm-application" ("dependencies:\n- base\n" ++ section)) `shouldSatisfy` has "effect/framework dependency"
  it "rejects concrete IO even in effect interfaces" $
    checkWorkspace (fixture ++ [("packages/hfm-application/src/Hfm/Application/Effects/Ports.hs", "port :: IO ()\n")]) `shouldSatisfy` has "concrete IO"
  it "keeps adapters independent" $
    forM_ [("hfm-tui", "Hfm.Infrastructure.Ports"), ("hfm-infrastructure", "Hfm.Tui.App")] $ \(package, imported) ->
      checkWorkspace (fixture ++ [("packages/" ++ package ++ "/src/Adapter.hs", "import " ++ imported)]) `shouldSatisfy` has "forbidden"
  it "rejects workspace drift in both build systems" $
    forM_ ["stack.yaml", "cabal.project"] $ \path ->
      checkWorkspace (replace path "packages:\n  packages/hfm-domain\n" fixture) `shouldSatisfy` has "workspace mismatch"
  it "rejects effect dependencies without imports" $
    checkWorkspace (manifest "hfm-domain" "dependencies:\n- base\n- directory\n") `shouldSatisfy` has "effect/framework dependency directory"
  it "ignores test dependencies and source comments" $ do
    checkWorkspace (manifest "hfm-domain" "dependencies:\n- base\ntests:\n  spec:\n    dependencies:\n    - hspec\n") `shouldBe` []
    checkWorkspace (source "-- import System.IO\n{- import System.Process\n IO {- nested -} -}\nimport Hfm.Application.Program\n") `shouldBe` []
  it "recognizes package-qualified imports and forbidden names" $ do
    checkWorkspace (source "import qualified \"process\" System.Process\n") `shouldSatisfy` has "effect/framework module"
    forM_ ["unsafePerformIO", "unsafeInterleaveIO", "foreign", "FileSystem", "Processes"] $ \name ->
      checkWorkspace (source (name ++ " value")) `shouldSatisfy` (not . null)
  it "keeps development tooling outside production packages" $
    checkWorkspace (manifest "hfm-tui" "dependencies:\n- base\n- hfm-dev-tools\n") `shouldSatisfy` has "forbidden dependency"
  it "reports missing required files" $
    checkWorkspace (filter ((/= "packages/hfm-domain/package.yaml") . fst) fixture) `shouldSatisfy` has "missing"
  it "recognizes qualified concrete effects and ports" $
    forM_ ["Prelude.IO", "Unsafe.unsafePerformIO", "P.FileSystem", "P.Processes"] $ \name ->
      checkWorkspace (source ("value :: " ++ name ++ " ()")) `shouldSatisfy` (not . null)
  it "ignores effect names and comment delimiters inside strings" $
    checkWorkspace (source "label = \"-- IO FileSystem\"\nother = \"{- System.IO -}\"\n") `shouldBe` []
  it "does not hide effects after character literals or promoted names" $
    forM_ ["'\"'", "'\\\"'", "'\\''", "'\\\\'", "'가'", "'Just", "''Example"] $ \literal ->
      checkWorkspace (source ("quote = " ++ literal ++ "\neffect :: IO ()\neffect = pure ()\n")) `shouldSatisfy` has "concrete IO"
  it "loads UTF-8 sources recursively from Unicode paths" $
    withSystemTempDirectory "hfm-workspace-" $ \root -> do
      let files = fixture ++ [("packages/hfm-application/src/한글/Nested.hs", "label = \"한글\"\nimport System.IO\n")]
      writeFixture root files
      snapshot <- readWorkspace root
      snapshot `shouldMatchList` files
      checkWorkspace snapshot `shouldSatisfy` has "effect/framework module System.IO"
  it "ignores tests, build caches and non-Haskell files when loading" $
    withSystemTempDirectory "hfm-workspace-" $ \root -> do
      writeFixture root (fixture ++ [(path, "import System.IO\n") | path <- ["packages/hfm-domain/test/Spec.hs", "packages/hfm-domain/.stack-work/Generated.hs", "packages/hfm-domain/src/notes.txt"]])
      snapshot <- readWorkspace root
      snapshot `shouldMatchList` fixture
      checkWorkspace snapshot `shouldBe` []

writeFixture :: FilePath -> Workspace -> IO ()
writeFixture root files = forM_ files $ \(path, contents) -> do
  let absolute = root </> path
  createDirectoryIfMissing True (takeDirectory absolute)
  withFile absolute WriteMode $ \handle -> do
    hSetEncoding handle utf8
    hPutStr handle contents

has :: String -> [String] -> Bool
has fragment = any (isInfixOf fragment)

fixture :: Workspace
fixture = [("stack.yaml", registration), ("cabal.project", registration)] ++
  [(folder ++ "/package.yaml", "dependencies:\n- base\nlibrary:\n  source-dirs: src\n") | folder <- workspaceFolders]
  where
    registration = "packages:\n" ++ unlines (map ("- " ++) workspaceFolders)

source :: String -> Workspace
source code = fixture ++ [("packages/hfm-application/src/Workflow.hs", code)]

manifest :: String -> String -> Workspace
manifest package contents = replace ("packages/" ++ package ++ "/package.yaml") contents fixture

replace :: FilePath -> String -> Workspace -> Workspace
replace path contents files = (path, contents) : filter ((/= path) . fst) files
