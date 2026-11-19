module Main
    ( main
    ) where

import           Fzh.Domain.Config
import qualified Fzh.Domain.Discovery as D
import qualified Fzh.Domain.Search    as S
import           Fzh.Domain.Session

import           Test.Hspec

main :: IO ()
main = hspec $ do
  describe "search" $ do
    it "ranks matches by gaps then path depth and preserves ties" $ do
      S.results (S.updateQuery "ab" (S.newSearch ["a/b", "axb", "ab", "AB", "zzz"]))
        `shouldBe` ["ab", "AB", "axb", "a/b"]
    it "matches Unicode case insensitively" $ do
      S.results (S.updateQuery "한a" (S.newSearch ["한글A", "다른파일"])) `shouldBe` ["한글A"]
    it "preserves full Unicode lowercase expansions and their gap scores" $ do
      S.fuzzyMatchScore "i\x0307" "İ" `shouldBe` Just 0
      S.fuzzyMatchScore "a" "İa" `shouldBe` Just 2
      S.filterItems "a" ["İa", "xa"] `shouldBe` ["xa", "İa"]
    it "clamps selection at both boundaries" $ do
      let search = S.newSearch ["a", "b"]
      S.selectedItem (S.moveSelection S.Previous search) `shouldBe` Just "a"
      S.selectedItem (iterate (S.moveSelection S.Next) search !! 5) `shouldBe` Just "b"
    it "clears selection for no matches and resets selection on query change" $ do
      let search = S.moveSelection S.Next (S.newSearch ["a", "b"])
      S.selectedItem (S.updateQuery "x" search) `shouldBe` Nothing
      S.selectedItem (S.updateQuery "" search) `shouldBe` Just "a"
  describe "session" $ do
    it "requests the initial selected preview" $ do
      let (state, commands) = transitionSession RequestPreview (newSession ["a", "b"] (80, 24))
      commands `shouldBe` [ReadPreview (PreviewRequest 0 "a")]
      browserPreview (sessionBrowser state) `shouldBe` Loading (PreviewRequest 0 "a")
    it "does not read for empty results" $ do
      let state = newSession [] (80, 24)
      transitionSession RequestPreview state `shouldBe` (state, [])
    it "avoids rereading the same selection and clears stale content" $ do
      let (loading, _) = transitionSession RequestPreview (newSession ["a", "b"] (80, 24))
          (loaded, _) = transitionSession (PreviewCompleted (PreviewRequest 0 "a") (Right "old")) loading
          (moved, commands) = transitionSession (Navigate S.Next) loaded
      transitionSession (Navigate S.Previous) loaded `shouldBe` (loaded, [])
      commands `shouldBe` [ReadPreview (PreviewRequest 1 "b")]
      browserPreview (sessionBrowser moved) `shouldBe` Loading (PreviewRequest 1 "b")
    it "represents preview failures separately from content" $ do
      let (loading, _) = transitionSession RequestPreview (newSession ["a"] (80, 24))
          (failed, commands) = transitionSession (PreviewCompleted (PreviewRequest 0 "a") (Left MissingFile)) loading
      browserPreview (sessionBrowser failed) `shouldBe` Failed "a" MissingFile
      commands `shouldBe` []
    it "ignores old replies even after returning to the same path" $ do
      let (first, _) = transitionSession RequestPreview (newSession ["a", "b"] (80, 24))
          (second, _) = transitionSession (Navigate S.Next) first
          (third, _) = transitionSession (Navigate S.Previous) second
      transitionSession (PreviewCompleted (PreviewRequest 0 "a") (Right "stale")) third
        `shouldBe` (third, [])
    it "clears preview when a query has no matches and restores it on clear" $ do
      let (loading, _) = transitionSession RequestPreview (newSession ["a"] (80, 24))
          (empty, commands) = transitionSession (EditQuery (Append 'x')) loading
          (restored, requests) = transitionSession (EditQuery Clear) empty
      browserPreview (sessionBrowser empty) `shouldBe` NoPreview
      commands `shouldBe` []
      S.selectedItem (browserSearch (sessionBrowser restored)) `shouldBe` Just "a"
      requests `shouldBe` [ReadPreview (PreviewRequest 1 "a")]
    it "deletes safely from an empty query and updates terminal size" $ do
      let state = newSession [] (80, 24)
      transitionSession (EditQuery Delete) state `shouldBe` (state, [])
      let (resized, commands) = transitionSession (TerminalResized 120 40) state
      browserSize (sessionBrowser resized) `shouldBe` (120, 40)
      commands `shouldBe` []
    it "distinguishes confirmation and dismissal and makes finished states absorbing" $ do
      let state = newSession ["a"] (80, 24)
      mapM_
        ( \(event, reason) -> do
            let (finished, commands) = transitionSession event state
            finished `shouldBe` Finished reason (sessionBrowser state)
            commands `shouldBe` [StopSession]
            mapM_
              (\late -> transitionSession late finished `shouldBe` (finished, []))
              [ RequestPreview
              , Navigate S.Next
              , EditQuery (Append 'x')
              , TerminalResized 20 10
              , PreviewCompleted (PreviewRequest 0 "a") (Right "late")
              , Confirm
              , Dismiss
              ]
        )
        [(Confirm, Confirmed), (Dismiss, Dismissed)]
  describe "configuration policy" $ do
    it "accepts vi and vim case insensitively and defaults unknown styles" $ do
      map parseBindingStyle ["vi", "VIM", "emacs", "unknown", "VİM"]
        `shouldBe` [Vim, Vim, Emacs, Emacs, Emacs]
  describe "discovery" $ do
    it "excludes hidden and build entries before issuing effects" $ do
      let (state, _) = D.startDiscovery "."
          (_, commands) =
            D.transitionDiscovery
              (D.DirectoryRead "." (Right [("./.git", ".git"), ("./build", "build"), ("./src", "src")]))
              state
      commands `shouldBe` [D.InspectPath "./src"]
    it "traverses directories and accumulates files" $ do
      let (start, _) = D.startDiscovery "."
          (inspect, _) = D.transitionDiscovery (D.DirectoryRead "." (Right [("./src", "src")])) start
          (listing, commands) = D.transitionDiscovery (D.PathInspected "./src" (Right D.Directory)) inspect
          (file, _) =
            D.transitionDiscovery (D.DirectoryRead "./src" (Right [("./src/a.hs", "a.hs")])) listing
          (done, effects) = D.transitionDiscovery (D.PathInspected "./src/a.hs" (Right D.RegularFile)) file
      commands `shouldBe` [D.ReadDirectory "./src"]
      D.discoveryResult done `shouldBe` Just (["./src/a.hs"], [])
      effects `shouldBe` []
      D.transitionDiscovery (D.DirectoryRead "." (Right [])) done `shouldBe` (done, [])
    it "records failures and continues the remaining paths" $ do
      let (start, _) = D.startDiscovery "."
          (first, _) =
            D.transitionDiscovery
              (D.DirectoryRead "." (Right [("./bad", "bad"), ("./ok", "ok")]))
              start
          (next, commands) = D.transitionDiscovery (D.PathInspected "./bad" (Left "denied")) first
          (done, _) = D.transitionDiscovery (D.PathInspected "./ok" (Right D.RegularFile)) next
      commands `shouldBe` [D.InspectPath "./ok"]
      D.discoveryResult done `shouldBe` Just (["./ok"], [D.DiscoveryIssue "./bad" "denied"])
    it "records a directory read failure and ignores mismatched replies" $ do
      let (state, _) = D.startDiscovery "."
      D.transitionDiscovery (D.DirectoryRead "other" (Right [])) state `shouldBe` (state, [])
      let (done, _) = D.transitionDiscovery (D.DirectoryRead "." (Left "denied")) state
      D.discoveryResult done `shouldBe` Just ([], [D.DiscoveryIssue "." "denied"])
