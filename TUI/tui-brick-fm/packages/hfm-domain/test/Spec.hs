module Main (main) where

import qualified Data.Vector as Vec
import Hfm.Domain.Input
import Hfm.Domain.Editor
import Hfm.Domain.Fuzzy
import Hfm.Domain.Selection
import Test.Hspec

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
  describe "Emacs 입력 편집" $ do
    it "커서를 이동해 중간에 입력하고 앞뒤 글자를 지운다" $ do
      editText (KeyPress (KChar 'b') [MCtrl]) "ab" 2 `shouldBe` Just ("ab", 1)
      editText (KeyPress (KChar 'x') []) "ab" 1 `shouldBe` Just ("axb", 2)
      editText (KeyPress (KChar 'h') [MCtrl]) "axb" 2 `shouldBe` Just ("ab", 1)
      editText (KeyPress (KChar 'd') [MCtrl]) "axb" 1 `shouldBe` Just ("ab", 1)
    it "처음과 끝으로 이동하고 단어 및 커서 뒤를 지운다" $ do
      editText (KeyPress (KChar 'a') [MCtrl]) "alpha beta" 5 `shouldBe` Just ("alpha beta", 0)
      editText (KeyPress (KChar 'e') [MCtrl]) "alpha beta" 5 `shouldBe` Just ("alpha beta", 10)
      editText (KeyPress (KChar 'w') [MCtrl]) "alpha beta" 10 `shouldBe` Just ("alpha ", 6)
      editText (KeyPress (KChar 'w') [MCtrl]) "/tmp/file" 9 `shouldBe` Just ("/tmp/", 5)
      editText (KeyPress (KChar 'k') [MCtrl]) "alpha beta" 6 `shouldBe` Just ("alpha ", 6)
      editText (KeyPress (KChar 'u') [MCtrl]) "alpha beta" 4 `shouldBe` Nothing
    it "Meta 단어 이동과 삭제를 Alt로도 처리한다" $ do
      editText (KeyPress (KChar 'b') [MMeta]) "alpha beta" 10 `shouldBe` Just ("alpha beta", 6)
      editText (KeyPress (KChar 'f') [MAlt]) "/tmp/file" 0 `shouldBe` Just ("/tmp/file", 4)
      editText (KeyPress (KChar 'd') [MAlt]) "alpha beta" 5 `shouldBe` Just ("alpha", 5)
      editText (KeyPress KBS [MMeta]) "/tmp/file" 9 `shouldBe` Just ("/tmp/", 5)
    it "입력 경계와 한글 커서를 처리한다" $ do
      editText (KeyPress (KChar 'b') [MMeta]) "" 0 `shouldBe` Just ("", 0)
      editText (KeyPress (KChar 'f') [MMeta]) "abc" 3 `shouldBe` Just ("abc", 3)
      editText (KeyPress (KChar 'd') [MCtrl]) "가나다" 1 `shouldBe` Just ("가다", 1)
      editText (KeyPress KHome []) "abc" 2 `shouldBe` Just ("abc", 0)
      editText (KeyPress KEnd []) "abc" 1 `shouldBe` Just ("abc", 3)

  describe "기존 검색 함수" $ do
    it "퍼지 일치를 계산한다" $ fuzzyMatchScore "ts" "test" `shouldBe` Just 1
    it "검색 결과를 필터링한다" $ Vec.length (filterItems "ab" (Vec.fromList ["abc", "xyz"])) `shouldBe` 1


  describe "Selection invariants" $ do
    it "keeps empty selections empty" $ do
      selectedElement (selectAt 99 (selection [] :: Selection Int)) `shouldBe` Nothing
    it "clamps movement and supports end selection" $ do
      let xs = selection [10 :: Int, 20, 30]
      selectedElement (selectAt (-1) xs) `shouldBe` Just (2, 30)
      selectedElement (selectStep (-1) xs) `shouldBe` Just (0, 10)
      selectedElement (selectStep 99 xs) `shouldBe` Just (2, 30)
