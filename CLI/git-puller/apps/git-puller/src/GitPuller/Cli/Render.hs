module GitPuller.Cli.Render (
  quoted,
  reason,
  outcome,
  summary,
  progress,
)
where

import Data.Char (ord, toUpper)
import GitPuller.Domain.Outcome (Outcome (..), Status (..), Summary (..), summarize)
import GitPuller.Domain.Repository (SkipReason (..))
import Numeric (showHex)

quoted :: String -> String
quoted text = "\"" <> concatMap escape text <> "\""
 where
  escape '"' = "\\\""
  escape '\\' = "\\\\"
  escape '\a' = "\\a"
  escape '\b' = "\\b"
  escape '\t' = "\\t"
  escape '\n' = "\\n"
  escape '\v' = "\\v"
  escape '\f' = "\\f"
  escape '\r' = "\\r"
  escape character
    | unprintable (ord character) = "\\x" <> map toUpper (showHex (ord character) ";")
    | otherwise = [character]
  unprintable code =
    code < 32 || (code >= 127 && code <= 159) || code == 0x2028 || code == 0x2029

reason :: SkipReason -> String
reason UnbornBranch = "unborn-branch"
reason MergeInProgress = "merge-in-progress"
reason RebaseInProgress = "rebase-in-progress"
reason DetachedHead = "detached-head"
reason NoUpstream = "no-upstream"
reason Dirty = "dirty"
reason Submodule = "submodule"

outcome :: Bool -> Outcome -> String
outcome verbose result = case status result of
  Updated -> "updated " <> location
  Planned -> "planned " <> location
  Skipped why -> "skipped " <> location <> " " <> reason why
  Failed diagnostic -> "failed " <> location <> " " <> (if verbose then quoted diagnostic else diagnostic)
 where
  location = quoted (path result)

summary :: [Outcome] -> String
summary outcomes =
  "Summary updated="
    <> show (updated counts)
    <> " planned="
    <> show (planned counts)
    <> " skipped="
    <> show (skipped counts)
    <> " failed="
    <> show (failed counts)
 where
  counts = summarize outcomes

progress :: Int -> Int -> String
progress completed total =
  "["
    <> replicate filled '#'
    <> replicate (width - filled) '-'
    <> "] "
    <> show completed
    <> "/"
    <> show total
    <> " processed"
 where
  width = 20
  filled
    | total == 0 = width
    | otherwise = width * completed `div` total
