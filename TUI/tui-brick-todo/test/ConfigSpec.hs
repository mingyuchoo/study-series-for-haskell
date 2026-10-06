{-# LANGUAGE OverloadedStrings #-}

module ConfigSpec
    ( spec
    ) where

import           Config

import qualified Graphics.Vty as V
import           Flow             ((<|))
import           Test.Hspec

spec :: Spec
spec = do
  describe "defaultKeyBindings" <| do
    it "기본 키바인딩이 정의되어 있어야 함" <| do
      quit defaultKeyBindings `shouldBe` ["q", "Esc"]
      add_todo defaultKeyBindings `shouldBe` ["a"]
      toggle_complete defaultKeyBindings `shouldBe` ["Space"]
      delete_todo defaultKeyBindings `shouldBe` ["d"]
      navigate_up defaultKeyBindings `shouldBe` ["Up", "k"]
      navigate_down defaultKeyBindings `shouldBe` ["Down", "j"]
      save_input defaultKeyBindings `shouldBe` ["Enter"]
      cancel_input defaultKeyBindings `shouldBe` ["Esc"]

  describe "keyToString" <| do
    it "일반 문자를 문자열로 변환해야 함" <| do
      keyToString (V.KChar 'a') `shouldBe` "a"
      keyToString (V.KChar 'z') `shouldBe` "z"

    it "공백 키를 Space로 변환해야 함" <| do
      keyToString (V.KChar ' ') `shouldBe` "Space"

    it "Enter 키를 변환해야 함" <| do
      keyToString V.KEnter `shouldBe` "Enter"

    it "Esc 키를 변환해야 함" <| do
      keyToString V.KEsc `shouldBe` "Esc"

    it "방향키를 변환해야 함" <| do
      keyToString V.KUp `shouldBe` "Up"
      keyToString V.KDown `shouldBe` "Down"
      keyToString V.KLeft `shouldBe` "Left"
      keyToString V.KRight `shouldBe` "Right"

    it "Backspace 키를 변환해야 함" <| do
      keyToString V.KBS `shouldBe` "Backspace"

    it "Function 키를 변환해야 함" <| do
      keyToString (V.KFun 1) `shouldBe` "F1"
      keyToString (V.KFun 12) `shouldBe` "F12"

  describe "matchesKey" <| do
    it "quit 키를 매칭해야 함" <| do
      matchesKey defaultKeyBindings (V.KChar 'q') `shouldBe` Just QuitApp

    it "add_todo 키를 매칭해야 함" <| do
      matchesKey defaultKeyBindings (V.KChar 'a') `shouldBe` Just AddTodo

    it "toggle_complete 키를 매칭해야 함" <| do
      matchesKey defaultKeyBindings (V.KChar ' ') `shouldBe` Just ToggleComplete

    it "delete_todo 키를 매칭해야 함" <| do
      matchesKey defaultKeyBindings (V.KChar 'd') `shouldBe` Just DeleteTodo

    it "navigate_up 키를 매칭해야 함" <| do
      matchesKey defaultKeyBindings V.KUp `shouldBe` Just NavigateUp
      matchesKey defaultKeyBindings (V.KChar 'k') `shouldBe` Just NavigateUp

    it "navigate_down 키를 매칭해야 함" <| do
      matchesKey defaultKeyBindings V.KDown `shouldBe` Just NavigateDown
      matchesKey defaultKeyBindings (V.KChar 'j') `shouldBe` Just NavigateDown

    it "save_input 키를 매칭해야 함" <| do
      matchesKey defaultKeyBindings V.KEnter `shouldBe` Just SaveInput

    it "cancel_input 키를 매칭해야 함" <| do
      -- Esc는 quit과 cancel_input 둘 다에 매핑되어 있으므로 첫 번째 매칭인 QuitApp이 반환됨
      matchesKey defaultKeyBindings V.KEsc `shouldBe` Just QuitApp

    it "매칭되지 않는 키는 Nothing을 반환해야 함" <| do
      matchesKey defaultKeyBindings (V.KChar 'x') `shouldBe` Nothing

  describe "getFirstKey" <| do
    it "키 리스트의 첫 번째 키를 반환해야 함" <| do
      getFirstKey ["a", "b", "c"] "default" `shouldBe` "a"

    it "빈 리스트면 기본값을 반환해야 함" <| do
      getFirstKey [] "default" `shouldBe` "default"

  describe "KeyAction" <| do
    it "모든 KeyAction이 Eq 인스턴스를 가져야 함" <| do
      QuitApp `shouldBe` QuitApp
      AddTodo `shouldBe` AddTodo
      ToggleComplete `shouldBe` ToggleComplete
      DeleteTodo `shouldBe` DeleteTodo
      NavigateUp `shouldBe` NavigateUp
      NavigateDown `shouldBe` NavigateDown
      SaveInput `shouldBe` SaveInput
      CancelInput `shouldBe` CancelInput

    it "다른 KeyAction은 같지 않아야 함" <| do
      QuitApp `shouldNotBe` AddTodo
      ToggleComplete `shouldNotBe` DeleteTodo
