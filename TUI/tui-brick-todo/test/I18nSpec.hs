{-# LANGUAGE OverloadedStrings #-}

module I18nSpec
  ( spec
  ) where

import I18n

import Flow ((<|))
import Test.Hspec

spec :: Spec
spec = do
  describe "Language" <| do
    it "English와 Korean이 다르게 비교되어야 함" <| do
      English `shouldNotBe` Korean

    it "같은 언어는 동일해야 함" <| do
      English `shouldBe` English
      Korean `shouldBe` Korean

  describe "defaultMessages" <| do
    it "기본 메시지는 영어여야 함" <| do
      language defaultMessages `shouldBe` "en"

    it "UI 메시지가 정의되어 있어야 함" <| do
      header (ui defaultMessages) `shouldBe` "📝 Todo Manager"
      todos_title (ui defaultMessages) `shouldBe` " Todos "
      detail_title (ui defaultMessages) `shouldBe` " Details "
      no_todos (ui defaultMessages) `shouldBe` "No todos yet. Press 'a' to add one!"

    it "필드 레이블이 정의되어 있어야 함" <| do
      id_label (fields defaultMessages) `shouldBe` "ID"
      status_label (fields defaultMessages) `shouldBe` "Status"
      action_label (fields defaultMessages) `shouldBe` "Action"
      subject_label (fields defaultMessages) `shouldBe` "Subject"

    it "상태 메시지가 정의되어 있어야 함" <| do
      completed (status defaultMessages) `shouldBe` "✓ Completed"
      in_progress (status defaultMessages) `shouldBe` "○ In Progress"

    it "리스트 메시지가 정의되어 있어야 함" <| do
      checkbox_done (list defaultMessages) `shouldBe` "[✓] "
      checkbox_todo (list defaultMessages) `shouldBe` "[ ] "
      field_separator (list defaultMessages) `shouldBe` " | "

    it "도움말 메시지가 정의되어 있어야 함" <| do
      add (help defaultMessages) `shouldBe` "Add"
      edit (help defaultMessages) `shouldBe` "Edit"
      toggle (help defaultMessages) `shouldBe` "Toggle"
      delete (help defaultMessages) `shouldBe` "Delete"
      quit (help defaultMessages) `shouldBe` "Quit"

    it "시스템 메시지가 정의되어 있어야 함" <| do
      config_not_found (messages defaultMessages) `shouldBe` "Configuration file not found"
      using_default (messages defaultMessages) `shouldBe` "Using default keybindings."

    it "샘플 todos가 정의되어 있어야 함" <| do
      welcome (sample_todos defaultMessages) `shouldBe` "Welcome to Todo Manager!"
      add_hint (sample_todos defaultMessages) `shouldBe` "Press 'a' to add a new todo"
      toggle_hint (sample_todos defaultMessages) `shouldBe` "Press Space to toggle completion"

  describe "UIMessages" <| do
    it "모든 UI 메시지 필드가 존재해야 함" <| do
      let uiMsgs = ui defaultMessages
      header uiMsgs `shouldSatisfy` (not . null)
      todos_title uiMsgs `shouldSatisfy` (not . null)
      detail_title uiMsgs `shouldSatisfy` (not . null)
      detail_edit_title uiMsgs `shouldSatisfy` (not . null)
      detail_add_title uiMsgs `shouldSatisfy` (not . null)
      no_todos uiMsgs `shouldSatisfy` (not . null)
      no_selection uiMsgs `shouldSatisfy` (not . null)
      not_found uiMsgs `shouldSatisfy` (not . null)

  describe "FieldLabels" <| do
    it "모든 필드 레이블이 존재해야 함" <| do
      let fieldMsgs = fields defaultMessages
      id_label fieldMsgs `shouldSatisfy` (not . null)
      status_label fieldMsgs `shouldSatisfy` (not . null)
      action_label fieldMsgs `shouldSatisfy` (not . null)
      action_required_label fieldMsgs `shouldSatisfy` (not . null)
      subject_label fieldMsgs `shouldSatisfy` (not . null)
      indirect_object_label fieldMsgs `shouldSatisfy` (not . null)
      direct_object_label fieldMsgs `shouldSatisfy` (not . null)
      created_at_label fieldMsgs `shouldSatisfy` (not . null)
      completed_at_label fieldMsgs `shouldSatisfy` (not . null)
      auto_generated_label fieldMsgs `shouldSatisfy` (not . null)

  describe "StatusMessages" <| do
    it "상태 메시지가 정의되어 있어야 함" <| do
      let statusMsgs = status defaultMessages
      completed statusMsgs `shouldSatisfy` (not . null)
      in_progress statusMsgs `shouldSatisfy` (not . null)

  describe "ListMessages" <| do
    it "리스트 표시 메시지가 정의되어 있어야 함" <| do
      let listMsgs = list defaultMessages
      checkbox_done listMsgs `shouldSatisfy` (not . null)
      checkbox_todo listMsgs `shouldSatisfy` (not . null)
      field_separator listMsgs `shouldSatisfy` (not . null)
      field_action listMsgs `shouldSatisfy` (not . null)
      field_subject listMsgs `shouldSatisfy` (not . null)
      field_indirect listMsgs `shouldSatisfy` (not . null)
      field_direct listMsgs `shouldSatisfy` (not . null)
      completed_prefix listMsgs `shouldSatisfy` (not . null)
      created_prefix listMsgs `shouldSatisfy` (not . null)

  describe "HelpMessages" <| do
    it "도움말 메시지가 정의되어 있어야 함" <| do
      let helpMsgs = help defaultMessages
      view_mode helpMsgs `shouldSatisfy` (not . null)
      edit_mode helpMsgs `shouldSatisfy` (not . null)
      input_mode helpMsgs `shouldSatisfy` (not . null)
      add helpMsgs `shouldSatisfy` (not . null)
      edit helpMsgs `shouldSatisfy` (not . null)
      toggle helpMsgs `shouldSatisfy` (not . null)
      delete helpMsgs `shouldSatisfy` (not . null)
      navigate helpMsgs `shouldSatisfy` (not . null)
      quit helpMsgs `shouldSatisfy` (not . null)

  describe "SystemMessages" <| do
    it "시스템 메시지가 정의되어 있어야 함" <| do
      let sysMsgs = messages defaultMessages
      config_not_found sysMsgs `shouldSatisfy` (not . null)
      config_load_failed sysMsgs `shouldSatisfy` (not . null)
      config_loaded sysMsgs `shouldSatisfy` (not . null)
      using_default sysMsgs `shouldSatisfy` (not . null)
      i18n_not_found sysMsgs `shouldSatisfy` (not . null)
      i18n_load_failed sysMsgs `shouldSatisfy` (not . null)
      i18n_loaded sysMsgs `shouldSatisfy` (not . null)
      using_default_lang sysMsgs `shouldSatisfy` (not . null)

  describe "SampleTodos" <| do
    it "샘플 todos가 정의되어 있어야 함" <| do
      let samples = sample_todos defaultMessages
      welcome samples `shouldSatisfy` (not . null)
      add_hint samples `shouldSatisfy` (not . null)
      toggle_hint samples `shouldSatisfy` (not . null)
