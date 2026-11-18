module WorkspaceView exposing (view)

import Html exposing (Html, a, button, div, footer, form, h1, h2, header, input, label, li, main_, nav, option, p, section, select, span, strong, text, time, ul)
import Html.Attributes exposing (attribute, class, disabled, for, href, id, placeholder, selected, type_, value)
import Html.Events exposing (onClick, onInput, onSubmit)
import Todo exposing (Status(..), Todo)
import Workspace exposing (Model, Msg(..))


view : Model -> Html Msg
view model =
    div [ class "page" ]
        [ header [ class "topbar" ]
            [ div [ class "shell topbar-inner" ]
                [ a [ class "brand", href "#" ]
                    [ span [ class "brand-mark", attribute "aria-hidden" "true" ] [ text "✓" ]
                    , text "Todo Workspace"
                    ]
                , a [ href "#tasks" ] [ text "Tasks" ]
                ]
            ]
        , main_ [ class "shell" ]
            [ section [ class "hero", attribute "aria-labelledby" "page-title" ]
                [ h1 [ id "page-title" ] [ text "Your task planner" ]
                , summary model
                ]
            , div [ class "feedback" ]
                [ p [ attribute "role" "status" ] [ text model.notice ]
                , case model.error of
                    Just error ->
                        p [ class "error", attribute "role" "alert" ] [ text error ]

                    Nothing ->
                        text ""
                ]
            , div [ class "workspace" ]
                [ taskForm model
                , taskList model
                ]
            ]
        , footer [] [ div [ class "shell" ] [ a [ href "#" ] [ text "Back to top" ] ] ]
        ]


summary : Model -> Html Msg
summary model =
    let
        count status =
            if model.loaded then
                String.fromInt (List.length (List.filter (\todo -> todo.status == status) model.todos))

            else
                "—"

        metric status caption =
            div [ class "metric" ]
                [ strong [] [ text (count status) ]
                , span [] [ text caption ]
                ]
    in
    section [ class "summary", attribute "aria-labelledby" "summary-title" ]
        [ h2 [ id "summary-title" ] [ text "At a glance" ]
        , div [ class "metrics" ]
            [ metric Pending "To do"
            , metric Doing "In progress"
            , metric Done "Done"
            ]
        ]


taskList : Model -> Html Msg
taskList model =
    let
        visible =
            case model.filter of
                Just status ->
                    List.filter (\todo -> todo.status == status) model.todos

                Nothing ->
                    model.todos

        tab filter caption =
            button
                [ type_ "button"
                , class "filter"
                , attribute "aria-pressed" (bool (model.filter == filter))
                , onClick (SetFilter filter)
                ]
                [ text caption ]
    in
    section [ class "task-panel", id "tasks", attribute "aria-labelledby" "list-title" ]
        [ header [ class "task-panel-header" ]
            [ h2 [ id "list-title" ] [ text "Your tasks" ]
            , nav [ class "filters", attribute "aria-label" "Filter tasks" ]
                [ tab Nothing "All"
                , tab (Just Pending) "To do"
                , tab (Just Doing) "In progress"
                , tab (Just Done) "Done"
                ]
            ]
        , div [ class "task-panel-body" ] [ taskResults model visible ]
        ]


taskResults : Model -> List Todo -> Html Msg
taskResults model visible =
    if model.loaded then
        if List.isEmpty visible then
            p [ class "empty" ]
                [ text
                    (if List.isEmpty model.todos then
                        "No tasks yet. Add one to get started."

                     else
                        "No tasks match this filter."
                    )
                ]

        else
            ul [ class "task-list" ] (List.map (taskRow model) visible)

    else if model.busy then
        p [ class "empty", attribute "role" "status" ] [ text "Loading tasks…" ]

    else
        div [ class "empty" ]
            [ p [] [ text "Could not load tasks." ]
            , action "secondary" "Try again" Reload False
            ]


taskRow : Model -> Todo -> Html Msg
taskRow model todo =
    let
        editing =
            Maybe.map .id model.editing == Just todo.id

        confirming =
            Maybe.map .id model.confirming == Just todo.id

        date =
            String.left 10 todo.createdAt

        pill kind name message =
            button
                [ type_ "button"
                , class ("pill " ++ kind ++ " " ++ String.toLower name)
                , attribute "aria-label" ("Change " ++ kind ++ " for " ++ todo.title ++ " (currently " ++ name ++ ")")
                , onClick message
                , disabled (model.busy || editing || confirming)
                ]
                [ text name ]
    in
    li [ class "task-row" ]
        [ div [ class "task-details" ]
            [ strong [] [ text todo.title ]
            , div [ class "task-meta" ]
                [ time [ attribute "datetime" todo.createdAt, attribute "title" todo.createdAt ] [ text date ]
                , pill "priority" (Todo.priorityName todo.priority) (CyclePriority todo)
                , pill "status" (Todo.statusName todo.status) (CycleStatus todo)
                ]
            ]
        , if confirming then
            div [ class "row-actions confirmation", attribute "role" "group", attribute "aria-label" ("Confirm deletion of " ++ todo.title) ]
                [ span [] [ text "Delete this task?" ]
                , action "secondary" "Cancel" CancelDelete model.busy
                , action "danger" "Delete task" (ConfirmDelete todo) model.busy
                ]

          else
            div [ class "row-actions" ]
                [ action "secondary" "Edit" (BeginEdit todo) model.busy
                , action "quiet" "Delete" (AskDelete todo) model.busy
                ]
        ]


taskForm : Model -> Html Msg
taskForm model =
    let
        isEditing =
            model.editing /= Nothing
    in
    section [ class "editor", attribute "aria-labelledby" "editor-title" ]
        [ h2 [ id "editor-title" ]
            [ text
                (if isEditing then
                    "Edit task"

                 else
                    "Add a task"
                )
            ]
        , form [ onSubmit Submit ]
            [ label [ for "todo-title" ] [ text "Task title" ]
            , input
                [ id "todo-title"
                , type_ "text"
                , placeholder "What needs to be done?"
                , value model.draft
                , onInput SetTitle
                , disabled model.busy
                ]
                []
            , case model.editing of
                Just todo ->
                    div [ class "editor-options" ]
                        [ dropdown "Priority" "todo-priority" Todo.priorities Todo.priorityName todo.priority SetPriority model.busy
                        , dropdown "Status" "todo-status" Todo.statuses Todo.statusName todo.status SetStatus model.busy
                        ]

                Nothing ->
                    text ""
            , div [ class "form-actions" ]
                [ button [ class "primary", type_ "submit", disabled (model.busy || not model.loaded || String.isEmpty (String.trim model.draft)) ]
                    [ text
                        (if isEditing then
                            "Save changes"

                         else
                            "Add task"
                        )
                    ]
                , if isEditing then
                    action "secondary" "Cancel" ResetForm model.busy

                  else
                    text ""
                ]
            ]
        ]


dropdown : String -> String -> List a -> (a -> String) -> a -> (a -> Msg) -> Bool -> Html Msg
dropdown caption fieldId choices name current message busy =
    div []
        [ label [ for fieldId ] [ text caption ]
        , select
            [ id fieldId
            , disabled busy
            , onInput
                (\selection ->
                    choices
                        |> List.filter (\choice -> name choice == selection)
                        |> List.head
                        |> Maybe.withDefault current
                        |> message
                )
            ]
            (List.map (\choice -> option [ value (name choice), selected (choice == current) ] [ text (name choice) ]) choices)
        ]


action : String -> String -> Msg -> Bool -> Html Msg
action style caption message busy =
    button [ class style, type_ "button", onClick message, disabled busy ] [ text caption ]


bool : Bool -> String
bool active =
    if active then
        "true"

    else
        "false"
