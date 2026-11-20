module Main (main) where

import GitPuller.Cli.Arguments (Command (..), Options (Options))
import GitPuller.Cli.Arguments qualified as Arguments
import GitPuller.Cli.Render qualified as Render
import GitPuller.Domain.Outcome (Outcome (..), Status (..))
import GitPuller.Domain.Repository (SkipReason (..))
import GitPuller.Domain.Update (Mode (..))
import Test.Hspec (Spec, describe, hspec, it, shouldBe)

main :: IO ()
main = hspec $ do
  argumentsSpec
  renderSpec

argumentsSpec :: Spec
argumentsSpec = describe "Arguments.parse" $ do
  let defaults = Options "projects" Apply False Arguments.defaultJobs
  it "accepts a lone help flag" $
    Arguments.parse ["--help"] `shouldBe` Right Help
  it "applies defaults to a bare path" $
    Arguments.parse ["projects"] `shouldBe` Right (Run defaults)
  it "accepts every option once in any order" $
    Arguments.parse ["--jobs", "16", "--verbose", "--dry-run", "projects"]
      `shouldBe` Right (Run (Options "projects" DryRun True 16))
  it "accepts a path starting with a hyphen after a separator" $
    Arguments.parse ["--", "-projects"]
      `shouldBe` Right (Run (Options "-projects" Apply False Arguments.defaultJobs))
  it "rejects repeated options" $ do
    Arguments.parse ["--dry-run", "--dry-run", "projects"] `shouldBe` Left "expected one path"
    Arguments.parse ["--verbose", "--verbose", "projects"] `shouldBe` Left "expected one path"
    Arguments.parse ["--jobs", "2", "--jobs", "2", "projects"] `shouldBe` Left "expected one path"
  it "rejects missing, empty, extra and unknown arguments" $ do
    Arguments.parse [] `shouldBe` Left "expected one path"
    Arguments.parse [""] `shouldBe` Left "expected one path"
    Arguments.parse ["--", ""] `shouldBe` Left "expected one path"
    Arguments.parse ["a", "b"] `shouldBe` Left "expected one path"
    Arguments.parse ["--unknown"] `shouldBe` Left "expected one path"
    Arguments.parse ["--help", "projects"] `shouldBe` Left "expected one path"
  it "rejects job counts that are not positive integers" $ do
    Arguments.parse ["--jobs", "0", "projects"] `shouldBe` Left "expected a positive job count"
    Arguments.parse ["--jobs", "many", "projects"] `shouldBe` Left "expected a positive job count"
    Arguments.parse ["--jobs", "-1", "projects"] `shouldBe` Left "expected a positive job count"
    Arguments.parse ["--jobs", "99999999999999999999999", "projects"]
      `shouldBe` Left "expected a positive job count"
  it "reads the argument after the jobs flag as the count" $ do
    Arguments.parse ["--jobs", "projects"] `shouldBe` Left "expected a positive job count"
    Arguments.parse ["--jobs"] `shouldBe` Left "expected one path"

renderSpec :: Spec
renderSpec = describe "Render" $ do
  it "quotes plain and non-ASCII text unchanged" $
    Render.quoted "/tmp/한글 repo" `shouldBe` "\"/tmp/한글 repo\""
  it "escapes quotes, backslashes and named control characters" $
    Render.quoted "a\"b\\c\a\b\t\n\v\f\r" `shouldBe` "\"a\\\"b\\\\c\\a\\b\\t\\n\\v\\f\\r\""
  it "escapes other control characters and line separators as hexadecimal" $
    Render.quoted "\ESC\DEL\x9F\x2028\x2029" `shouldBe` "\"\\x1B;\\x7F;\\x9F;\\x2028;\\x2029;\""
  it "renders each outcome status" $ do
    Render.outcome False (Outcome "a" Updated) `shouldBe` "updated \"a\""
    Render.outcome False (Outcome "a" Planned) `shouldBe` "planned \"a\""
    Render.outcome False (Outcome "a" (Skipped DetachedHead)) `shouldBe` "skipped \"a\" detached-head"
  it "quotes a failure diagnostic only when verbose" $ do
    Render.outcome False (Outcome "a" (Failed "line\n")) `shouldBe` "failed \"a\" line\n"
    Render.outcome True (Outcome "a" (Failed "line\n")) `shouldBe` "failed \"a\" \"line\\n\""
  it "summarizes outcome counts" $
    Render.summary [Outcome "a" Updated, Outcome "b" (Failed "x"), Outcome "c" (Skipped Dirty)]
      `shouldBe` "Summary updated=1 planned=0 skipped=1 failed=1"
  it "draws a proportional progress bar" $ do
    Render.progress 0 0 `shouldBe` "[####################] 0/0 processed"
    Render.progress 1 4 `shouldBe` "[#####---------------] 1/4 processed"
    Render.progress 5 5 `shouldBe` "[####################] 5/5 processed"
