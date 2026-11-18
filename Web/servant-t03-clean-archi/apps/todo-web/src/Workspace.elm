module Workspace exposing (Model, Msg(..), Operation(..), init, update)

import Browser.Dom
import Task
import Todo exposing (Priority, Status, Todo)
import TodoApi


type alias Model =
    { todos : List Todo
    , draft : String
    , editing : Maybe Todo
    , confirming : Maybe Todo
    , filter : Maybe Status
    , busy : Bool
    , loaded : Bool
    , error : Maybe String
    , notice : String
    }


type Operation
    = Load
    | Create
    | Save Int
    | Change Int
    | Remove Int


type Msg
    = Reload
    | SetFilter (Maybe Status)
    | SetTitle String
    | SetPriority Priority
    | SetStatus Status
    | BeginEdit Todo
    | ResetForm
    | Submit
    | CyclePriority Todo
    | CycleStatus Todo
    | AskDelete Todo
    | CancelDelete
    | ConfirmDelete Todo
    | Received Operation (Result String (List Todo))
    | Focused (Result Browser.Dom.Error ())


init : () -> ( Model, Cmd Msg )
init _ =
    start Load
        (TodoApi.fetch (Received Load))
        { todos = []
        , draft = ""
        , editing = Nothing
        , confirming = Nothing
        , filter = Nothing
        , busy = False
        , loaded = False
        , error = Nothing
        , notice = ""
        }


start : Operation -> Cmd Msg -> Model -> ( Model, Cmd Msg )
start operation command model =
    ( { model
        | busy = True
        , error = Nothing
        , notice = ""
        , loaded = model.loaded && operation /= Load
      }
    , command
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    case message of
        Received operation result ->
            receive operation result { model | busy = False }

        SetFilter filter ->
            ( { model | filter = filter }, Cmd.none )

        Focused result ->
            case result of
                Ok () ->
                    ( model, Cmd.none )

                Err _ ->
                    ( { model | error = Just "Could not move focus. Use Tab to reach the task form." }, Cmd.none )

        _ ->
            if model.busy then
                ( model, Cmd.none )

            else
                interact message model


interact : Msg -> Model -> ( Model, Cmd Msg )
interact message model =
    case message of
        Reload ->
            start Load (TodoApi.fetch (Received Load)) model

        SetTitle title ->
            ( { model | draft = title }, Cmd.none )

        SetPriority priority ->
            ( { model | editing = Maybe.map (\todo -> { todo | priority = priority }) model.editing }, Cmd.none )

        SetStatus status ->
            ( { model | editing = Maybe.map (\todo -> { todo | status = status }) model.editing }, Cmd.none )

        BeginEdit todo ->
            ( { model | editing = Just todo, draft = todo.title, error = Nothing, confirming = Nothing }
            , focusTitle
            )

        ResetForm ->
            ( clearForm model, focusTitle )

        Submit ->
            submit model

        CyclePriority todo ->
            change { todo | priority = Todo.nextPriority todo.priority } model

        CycleStatus todo ->
            change { todo | status = Todo.nextStatus todo.status } model

        AskDelete todo ->
            ( { model | confirming = Just todo, error = Nothing }, Cmd.none )

        CancelDelete ->
            ( { model | confirming = Nothing, error = Nothing }, Cmd.none )

        ConfirmDelete todo ->
            start (Remove todo.id) (TodoApi.delete todo.id (Received (Remove todo.id))) model

        _ ->
            ( model, Cmd.none )


clearForm : Model -> Model
clearForm model =
    { model | draft = "", editing = Nothing, error = Nothing }


focusTitle : Cmd Msg
focusTitle =
    Task.attempt Focused (Browser.Dom.focus "todo-title")


submit : Model -> ( Model, Cmd Msg )
submit model =
    let
        title =
            String.trim model.draft

        length =
            List.length (String.toList title)
    in
    if length < 3 || length > 50 then
        ( { model | error = Just "Enter a task title between 3 and 50 characters.", notice = "" }, focusTitle )

    else
        case model.editing of
            Just todo ->
                let
                    operation =
                        Save todo.id
                in
                start operation (TodoApi.update { todo | title = title } (Received operation)) model

            Nothing ->
                start Create (TodoApi.create title (Received Create)) model


change : Todo -> Model -> ( Model, Cmd Msg )
change todo model =
    let
        operation =
            Change todo.id
    in
    start operation (TodoApi.update todo (Received operation)) model


receive : Operation -> Result String (List Todo) -> Model -> ( Model, Cmd Msg )
receive operation result model =
    case result of
        Ok todos ->
            reconcile operation todos model

        Err error ->
            ( { model | error = Just error }, Cmd.none )


reconcile : Operation -> List Todo -> Model -> ( Model, Cmd Msg )
reconcile operation todos model =
    case operation of
        Load ->
            ( { model | todos = List.sortBy (\todo -> negate todo.id) todos, loaded = True }, Cmd.none )

        Create ->
            ( clearForm { model | todos = todos ++ model.todos, filter = Nothing, notice = "Task added." }, focusTitle )

        Save id ->
            ( clearForm { model | todos = replace id todos model.todos, notice = "Task saved." }, focusTitle )

        Change id ->
            ( { model | todos = replace id todos model.todos, notice = "Task updated." }, Cmd.none )

        Remove id ->
            let
                updated =
                    { model
                        | todos = List.filter (\todo -> todo.id /= id) model.todos
                        , confirming = Nothing
                        , notice = "Task deleted."
                    }
            in
            ( if Maybe.map .id model.editing == Just id then
                clearForm updated

              else
                updated
            , Cmd.none
            )


replace : Int -> List Todo -> List Todo -> List Todo
replace id replacement =
    List.concatMap
        (\todo ->
            if todo.id == id then
                replacement

            else
                [ todo ]
        )
