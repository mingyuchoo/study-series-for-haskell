module Todo.Application.Workflow
  ( module Todo.Application.Types
  , emptyForm
  , initialWorkflow
  , transition
  , currentForm
  , workflowError
  ) where

import Data.List (find, findIndex)
import Data.Maybe (fromMaybe, listToMaybe)
import Todo.Application.Form
import Todo.Application.Types
import Todo.Domain.Model (Todo (..))
import TodoStatus (nextStatus)

initialWorkflow :: Workflow
initialWorkflow = Workflow [] Nothing NotStarted

currentForm :: Phase -> Maybe Form
currentForm (Creating form) = Just form
currentForm (Editing _ form) = Just form
currentForm (Awaiting (InsertingTodo form _)) = Just form
currentForm (Awaiting (UpdatingTodo _ form _)) = Just form
currentForm (Failed _ (RecoverCreating form)) = Just form
currentForm (Failed _ (RecoverEditing _ form)) = Just form
currentForm _ = Nothing

workflowError :: Workflow -> Maybe WorkflowError
workflowError workflow = case phase workflow of
  Failed problem _ -> Just problem
  _ -> Nothing

transition :: Event -> Workflow -> (Workflow, [Command])
transition event workflow = case phase workflow of
  Stopped -> unchanged workflow
  _ | event == Quit -> unchanged workflow {phase = Stopped}
  Awaiting pending -> case event of
    Succeeded result -> complete pending result workflow
    Rejected problem -> unchanged workflow {phase = Failed problem $ recovery pending}
    _ -> unchanged workflow
  NotStarted -> case event of
    Start -> begin FetchingTodos workflow
    _ -> unchanged workflow
  Browsing -> browse event workflow
  Creating form -> create event form workflow
  Editing todo form -> edit event todo form workflow
  Failed _ RecoverLoading -> case event of
    Start -> begin FetchingTodos workflow
    Retry -> begin FetchingTodos workflow
    Cancel -> unchanged workflow {phase = Stopped}
    _ -> unchanged workflow
  Failed _ recover -> case event of
    Succeeded _ -> unchanged workflow
    Rejected _ -> unchanged workflow
    Cancel -> unchanged workflow {phase = Browsing}
    DismissError -> unchanged workflow {phase = restore recover}
    Retry -> retry recover workflow
    _ -> transition event workflow {phase = restore recover}

unchanged :: Workflow -> (Workflow, [Command])
unchanged workflow = (workflow, [])

browse :: Event -> Workflow -> (Workflow, [Command])
browse BeginCreate workflow = unchanged workflow {phase = Creating emptyForm}
browse BeginEdit workflow = case selectedTodo workflow of
  Nothing -> unchanged workflow
  Just todo -> unchanged workflow {phase = Editing todo $ formFromTodo todo}
browse DeleteSelected workflow = case selectedTodo workflow of
  Nothing -> unchanged workflow
  Just todo -> begin (RemovingTodo $ identifier todo) workflow
browse CycleSelected workflow = case selectedTodo workflow of
  Nothing -> unchanged workflow
  Just todo ->
    begin (AdvancingTodo (identifier todo) (status todo) (nextStatus $ status todo)) workflow
browse MoveUp workflow = unchanged $ moveSelection (-1) workflow
browse MoveDown workflow = unchanged $ moveSelection 1 workflow
browse _ workflow = unchanged workflow

create :: Event -> Form -> Workflow -> (Workflow, [Command])
create Submit form workflow = case formFields form of
  Left problem -> unchanged workflow {phase = Failed (InvalidFields problem) $ RecoverCreating form}
  Right value -> begin (InsertingTodo form value) workflow
create Cancel _ workflow = unchanged workflow {phase = Browsing}
create FocusNext form workflow = unchanged workflow {phase = Creating $ advanceFocus form}
create (ChangeField field value) form workflow = unchanged workflow {phase = Creating $ updateField field value form}
create _ _ workflow = unchanged workflow

edit :: Event -> Todo -> Form -> Workflow -> (Workflow, [Command])
edit Submit todo form workflow = case formFields form of
  Left problem -> unchanged workflow {phase = Failed (InvalidFields problem) $ RecoverEditing todo form}
  Right value -> begin (UpdatingTodo todo form value) workflow
edit Cancel _ _ workflow = unchanged workflow {phase = Browsing}
edit FocusNext todo form workflow = unchanged workflow {phase = Editing todo $ advanceFocus form}
edit (ChangeField field value) todo form workflow = unchanged workflow {phase = Editing todo $ updateField field value form}
edit _ _ _ workflow = unchanged workflow

begin :: Pending -> Workflow -> (Workflow, [Command])
begin pending workflow = (workflow {phase = Awaiting pending}, [command pending])

command :: Pending -> Command
command FetchingTodos = LoadTodos
command (InsertingTodo _ value) = InsertTodo value
command (UpdatingTodo todo _ value) = UpdateFields (identifier todo) value
command (RemovingTodo target) = RemoveTodo target
command (AdvancingTodo target before after) = SetStatus target before after

recovery :: Pending -> Recovery
recovery FetchingTodos = RecoverLoading
recovery (InsertingTodo form _) = RecoverCreating form
recovery (UpdatingTodo todo form _) = RecoverEditing todo form
recovery (RemovingTodo target) = RecoverDeleting target
recovery (AdvancingTodo target before after) = RecoverAdvancing target before after

restore :: Recovery -> Phase
restore RecoverLoading = NotStarted
restore (RecoverDeleting _) = Browsing
restore RecoverAdvancing {} = Browsing
restore (RecoverCreating form) = Creating form
restore (RecoverEditing todo form) = Editing todo form

retry :: Recovery -> Workflow -> (Workflow, [Command])
retry RecoverLoading workflow = begin FetchingTodos workflow
retry (RecoverDeleting target) workflow = begin (RemovingTodo target) workflow
retry (RecoverAdvancing target before after) workflow = begin (AdvancingTodo target before after) workflow
retry recover workflow = transition Submit workflow {phase = restore recover}

selectedTodo :: Workflow -> Maybe Todo
selectedTodo workflow =
  selectedId workflow >>= \target -> find ((== target) . identifier) (workflowTodos workflow)

moveSelection :: Int -> Workflow -> Workflow
moveSelection offset workflow =
  let todos = workflowTodos workflow
      position = selectedId workflow >>= \target -> findIndex ((== target) . identifier) todos
      index = max 0 $ min (length todos - 1) $ maybe 0 (+ offset) position
   in workflow {selectedId = identifier <$> listToMaybe (drop index todos)}

complete :: Pending -> Result -> Workflow -> (Workflow, [Command])
complete FetchingTodos (TodosLoaded todos) workflow =
  unchanged
    workflow
      { workflowTodos = todos
      , selectedId = identifier <$> listToMaybe todos
      , phase = Browsing
      }
complete (InsertingTodo _ _) (TodoCreated todo) workflow =
  unchanged
    workflow
      { workflowTodos = todo : workflowTodos workflow
      , selectedId = Just $ identifier todo
      , phase = Browsing
      }
complete (UpdatingTodo target _ _) (TodoUpdated todo) workflow
  | identifier target == identifier todo = replaceTodo todo workflow
complete (AdvancingTodo target _ expected) (StatusChanged todo) workflow
  | target == identifier todo && status todo == expected = replaceTodo todo workflow
complete (RemovingTodo target) (TodoDeleted actual) workflow
  | target == actual =
      let old = workflowTodos workflow
          remaining = filter ((/= target) . identifier) old
          index = fromMaybe 0 $ findIndex ((== target) . identifier) old
          next = listToMaybe $ drop (min index $ length remaining - 1) remaining
       in unchanged
            workflow {workflowTodos = remaining, selectedId = identifier <$> next, phase = Browsing}
complete _ _ workflow = unchanged workflow

replaceTodo :: Todo -> Workflow -> (Workflow, [Command])
replaceTodo todo workflow =
  unchanged
    workflow
      { workflowTodos =
          map (\old -> if identifier old == identifier todo then todo else old) $
            workflowTodos workflow
      , phase = Browsing
      }
