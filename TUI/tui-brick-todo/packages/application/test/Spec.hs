module Main (main) where

import Test.Hspec hiding (pending)
import Todo.Application.Workflow
import Todo.Domain.Model
import TodoStatus

sampleFields :: TodoFields
sampleFields = either (error . show) id $ validateFields "original" Nothing Nothing Nothing

todo :: Todo
todo = Todo 7 sampleFields Registered "2026-11-19 10:00" Nothing

loaded :: Workflow
loaded =
  fst $ transition (Succeeded (TodosLoaded [todo])) $ fst $ transition Start initialWorkflow

apply :: Event -> Workflow -> Workflow
apply event = fst . transition event

main :: IO ()
main = hspec $ do
  describe "startup" $ do
    it "loads through an explicit command" $ do
      transition Start initialWorkflow
        `shouldBe` (Workflow [] Nothing (Awaiting FetchingTodos), [LoadTodos])
    it "selects the first loaded item" $ do
      selectedId loaded `shouldBe` Just 7
      phase loaded `shouldBe` Browsing
    it "ignores results before startup" $
      apply (Succeeded (TodosLoaded [todo])) initialWorkflow `shouldBe` initialWorkflow
    it "retries a failed load" $ do
      let failed = apply (Rejected (RepositoryFailure "offline")) $ apply Start initialWorkflow
      snd (transition Retry failed) `shouldBe` [LoadTodos]
    it "keeps startup failures visible for unsupported actions" $ do
      let failed = apply (Rejected (RepositoryFailure "offline")) $ apply Start initialWorkflow
      apply BeginCreate failed `shouldBe` failed
      apply DismissError failed `shouldBe` failed
    it "restarts a failed load with Start" $ do
      let failed = apply (Rejected (RepositoryFailure "offline")) $ apply Start initialWorkflow
      snd (transition Start failed) `shouldBe` [LoadTodos]
  describe "forms" $ do
    it "starts with an empty creation form" $
      phase (apply BeginCreate loaded) `shouldBe` Creating emptyForm
    it "rejects an empty action without a command" $ do
      let (invalid, commands) = transition Submit $ apply BeginCreate loaded
      commands `shouldBe` []
      workflowError invalid `shouldBe` Just (InvalidFields EmptyAction)
      currentForm (phase invalid) `shouldBe` Just emptyForm
    it "normalizes creation fields in its command" $ do
      let draft = apply (ChangeField FocusAction "  new   task ") $ apply BeginCreate loaded
      case snd (transition Submit draft) of
        [InsertTodo value] -> action value `shouldBe` "new task"
        actual -> expectationFailure $ show actual
    it "retains failed edits and retries the same target" $ do
      let draft = apply (ChangeField FocusAction "changed") $ apply BeginEdit loaded
          pending = apply Submit draft
          failed = apply (Rejected (RepositoryFailure "offline")) pending
      fmap formAction (currentForm (phase failed)) `shouldBe` Just "changed"
      snd (transition Retry failed) `shouldBe` snd (transition Submit draft)
      workflowTodos failed `shouldBe` [todo]
    it "cancels a failed form without persisting" $ do
      let failed = apply Submit $ apply BeginCreate loaded
      phase (apply Cancel failed) `shouldBe` Browsing
      snd (transition Cancel failed) `shouldBe` []
    it "cycles focus over all fields" $ do
      let draft = apply BeginCreate loaded
      map (fmap formFocus . currentForm . phase) (take 5 (iterate (apply FocusNext) draft))
        `shouldBe` map Just [FocusAction, FocusSubject, FocusIndirectObject, FocusDirectObject, FocusAction]
    it "rejects an empty edited action" $ do
      let draft = apply (ChangeField FocusAction " ") $ apply BeginEdit loaded
      snd (transition Submit draft) `shouldBe` []
      workflowError (apply Submit draft) `shouldBe` Just (InvalidFields EmptyAction)
  describe "pending operations" $ do
    it "ignores duplicate save input while pending" $ do
      let pending = apply Submit $ apply BeginEdit loaded
      transition Submit pending `shouldBe` (pending, [])
    it "ignores a result for the wrong operation" $ do
      let pending = apply Submit $ apply BeginEdit loaded
      apply (Succeeded (TodoDeleted 7)) pending `shouldBe` pending
    it "ignores a result for a different target" $ do
      let pending = apply Submit $ apply BeginEdit loaded
      apply (Succeeded (TodoUpdated todo {identifier = 9})) pending `shouldBe` pending
    it "uses confirmed data after save" $ do
      let pending = apply Submit $ apply BeginEdit loaded
          updated = todo {changedAt = Just "confirmed"}
          saved = apply (Succeeded (TodoUpdated updated)) pending
      workflowTodos saved `shouldBe` [updated]
      phase saved `shouldBe` Browsing
    it "removes only the confirmed deleted item" $ do
      let pending = apply DeleteSelected loaded
          deleted = apply (Succeeded (TodoDeleted 7)) pending
      workflowTodos deleted `shouldBe` []
      selectedId deleted `shouldBe` Nothing
    it "advances typed status through a command" $
      snd (transition CycleSelected loaded) `shouldBe` [SetStatus 7 Registered InProgress]
    it "retries failed deletions with the original command" $ do
      let failed = apply (Rejected (RepositoryFailure "offline")) $ apply DeleteSelected loaded
      snd (transition Retry failed) `shouldBe` [RemoveTodo 7]
    it "retries failed status changes with their expected source status" $ do
      let failed = apply (Rejected (RepositoryFailure "offline")) $ apply CycleSelected loaded
      snd (transition Retry failed) `shouldBe` [SetStatus 7 Registered InProgress]
  describe "selection and termination" $ do
    it "can terminate while awaiting a result" $ do
      let stopped = apply Quit $ apply Start initialWorkflow
      phase stopped `shouldBe` Stopped
      apply (Succeeded (TodosLoaded [todo])) stopped `shouldBe` stopped
    it "does nothing without a selection" $ do
      let empty = apply (Succeeded (TodosLoaded [])) $ apply Start initialWorkflow
      map (snd . (`transition` empty)) [BeginEdit, DeleteSelected, CycleSelected]
        `shouldBe` [[], [], []]
    it "clamps navigation and keeps editing the selected ID" $ do
      let second = todo {identifier = 12}
          two = apply (Succeeded (TodosLoaded [todo, second])) $ apply Start initialWorkflow
          moved = apply MoveDown $ apply MoveDown two
      selectedId moved `shouldBe` Just 12
      case phase (apply BeginEdit moved) of
        Editing target _ -> identifier target `shouldBe` 12
        actual -> expectationFailure $ show actual
    it "ignores all events after quitting" $ do
      let stopped = apply Quit loaded
      phase stopped `shouldBe` Stopped
      map (`transition` stopped) [Start, BeginCreate, Succeeded (TodosLoaded [])]
        `shouldBe` replicate 3 (stopped, [])
