{-# LANGUAGE OverloadedStrings #-}

module UI.EventsSpec
  ( spec
  ) where

import Config qualified
import Flow ((<|))
import Graphics.Vty qualified as V
import I18n qualified
import Test.Hspec
import Todo.Application.Workflow qualified as Workflow
import UI.Events
import UI.Types

spec :: Spec
spec = do
  describe "workflow key translation" $ do
    let base = initialState Config.defaultKeyBindings I18n.defaultMessages
        loaded =
          fst
            $ Workflow.transition (Workflow.Succeeded (Workflow.TodosLoaded []))
            $ fst
            $ Workflow.transition Workflow.Start Workflow.initialWorkflow
        browsing = projectWorkflow loaded base
        creating = projectWorkflow (fst $ Workflow.transition Workflow.BeginCreate loaded) browsing
    it "cancels forms with Escape despite overlapping quit bindings" $
      keyEvent creating V.KEsc [] `shouldBe` Just Workflow.Cancel
    it "quits from browsing with Escape" $
      keyEvent browsing V.KEsc [] `shouldBe` Just Workflow.Quit
    it "saves forms with Enter" $
      keyEvent creating V.KEnter [] `shouldBe` Just Workflow.Submit
    it "keeps normal shortcut letters as text while editing" $
      keyEvent creating (V.KChar 'q') [] `shouldBe` Nothing
    it "cycles form focus with Tab" $
      keyEvent creating (V.KChar '\t') [] `shouldBe` Just Workflow.FocusNext
    it "honors modifier-based save bindings" $ do
      let keys = Config.defaultKeyBindings {Config.save_input = ["C-s"]}
          configured = creating {_configuredKeys = keys}
      keyEvent configured (V.KChar 's') [V.MCtrl] `shouldBe` Just Workflow.Submit
      keyEvent configured (V.KChar 's') [] `shouldBe` Nothing

  describe "trim" <| do
    it "앞뒤 공백을 제거해야 함" <| do
      trim "  hello  " `shouldBe` "hello"

    it "중간의 여러 공백을 하나로 줄여야 함" <| do
      trim "hello   world" `shouldBe` "hello world"

    it "빈 문자열은 빈 문자열을 반환해야 함" <| do
      trim "" `shouldBe` ""

    it "공백만 있는 문자열은 빈 문자열을 반환해야 함" <| do
      trim "   " `shouldBe` ""

    it "개행문자와 탭도 처리해야 함" <| do
      trim "\n\thello\t\n" `shouldBe` "hello"

    it "여러 줄의 공백을 처리해야 함" <| do
      trim "hello\n\n\nworld" `shouldBe` "hello world"

    it "탭과 공백이 섞인 경우를 처리해야 함" <| do
      trim "\t  hello  \t  world  \t" `shouldBe` "hello world"

    it "단일 단어는 그대로 반환해야 함" <| do
      trim "hello" `shouldBe` "hello"

    it "이미 정리된 문자열은 그대로 반환해야 함" <| do
      trim "hello world" `shouldBe` "hello world"

    it "한글 문자열의 공백도 처리해야 함" <| do
      trim "  안녕  하세요  " `shouldBe` "안녕 하세요"

    it "유니코드와 공백이 섞인 복합 문자열을 처리해야 함" <| do
      trim "  hello  세계  world  " `shouldBe` "hello 세계 world"

    it "단일 공백은 빈 문자열을 반환해야 함" <| do
      trim " " `shouldBe` ""
