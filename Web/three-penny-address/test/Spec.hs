-- {-# OPTIONS_GHC -F -pgmF doctest-discover #-}
-- {-# OPTIONS_GHC -F -pgmF hspec-discover   #-}

import Test.Hspec
import qualified Paths_ThreepennyAddress as Paths
import Control.Exception (bracket_)
import Data.Version (Version(..))
import System.Environment (setEnv, unsetEnv)
import Tests.UnitTests (unitTests)

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
    describe "Given Prelude" $ do
        context "when use `read` function" $ do
            it "should parse integers" $ do
                read "10" `shouldBe` (10 :: Int)
            it "should parse floating-point numbers" $ do
                read "2.5" `shouldBe` (2.5 :: Float)
    
    describe "Core Logic Tests" $ do
        unitTests

    describe "Generated package paths" $ do
        it "exposes the package version" $ do
            Paths.version `shouldBe` Version [0, 1, 0, 0] []

        it "returns configured installation directories" $ do
            shouldReturnNonEmptyPath Paths.getBinDir
            shouldReturnNonEmptyPath Paths.getLibDir
            shouldReturnNonEmptyPath Paths.getDynLibDir
            shouldReturnNonEmptyPath Paths.getDataDir
            shouldReturnNonEmptyPath Paths.getLibexecDir
            shouldReturnNonEmptyPath Paths.getSysconfDir

        it "honors path environment overrides" $ do
            withPathEnv $ do
                Paths.getBinDir `shouldReturn` "/tmp/threepenny/bin"
                Paths.getLibDir `shouldReturn` "/tmp/threepenny/lib"
                Paths.getDynLibDir `shouldReturn` "/tmp/threepenny/dynlib"
                Paths.getDataDir `shouldReturn` "/tmp/threepenny/data"
                Paths.getLibexecDir `shouldReturn` "/tmp/threepenny/libexec"
                Paths.getSysconfDir `shouldReturn` "/tmp/threepenny/etc"

        it "joins data file names with package data directories" $ do
            withDataDir "/tmp/threepenny/data/" $
                Paths.getDataFileName "index.html" `shouldReturn` "/tmp/threepenny/data/index.html"
            withDataDir "/tmp/threepenny/data" $
                Paths.getDataFileName "" `shouldReturn` "/tmp/threepenny/data"

shouldReturnNonEmptyPath :: IO FilePath -> Expectation
shouldReturnNonEmptyPath action = do
    path <- action
    path `shouldSatisfy` (not . null)

withPathEnv :: IO a -> IO a
withPathEnv =
    bracket_
        (do
            setEnv "ThreepennyAddress_bindir" "/tmp/threepenny/bin"
            setEnv "ThreepennyAddress_libdir" "/tmp/threepenny/lib"
            setEnv "ThreepennyAddress_dynlibdir" "/tmp/threepenny/dynlib"
            setEnv "ThreepennyAddress_datadir" "/tmp/threepenny/data"
            setEnv "ThreepennyAddress_libexecdir" "/tmp/threepenny/libexec"
            setEnv "ThreepennyAddress_sysconfdir" "/tmp/threepenny/etc")
        clearPathEnv

withDataDir :: FilePath -> IO a -> IO a
withDataDir dir =
    bracket_
        (setEnv "ThreepennyAddress_datadir" dir)
        (unsetEnv "ThreepennyAddress_datadir")

clearPathEnv :: IO ()
clearPathEnv = do
    unsetEnv "ThreepennyAddress_bindir"
    unsetEnv "ThreepennyAddress_libdir"
    unsetEnv "ThreepennyAddress_dynlibdir"
    unsetEnv "ThreepennyAddress_datadir"
    unsetEnv "ThreepennyAddress_libexecdir"
    unsetEnv "ThreepennyAddress_sysconfdir"
