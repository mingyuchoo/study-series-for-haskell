module Presentation.TaskBoard exposing (view)

import Application.TaskBoard exposing (AuthMode(..), Model, Msg(..), selectedTask)
import Domain.Task as Task exposing (Importance, Status, Task, Urgency)
import Html exposing (Html, aside, button, dd, div, dl, dt, h1, h2, h3, input, label, option, p, select, span, text, textarea)
import Html.Attributes exposing (attribute, checked, class, disabled, for, id, name, placeholder, selected, tabindex, type_, value)
import Html.Events exposing (on, onClick, onInput, preventDefaultOn)
import Json.Decode as Decode


view : Model -> Html Msg
view model =
    case model.session of
        Nothing ->
            authView model

        Just _ ->
            div [ class "page-shell" ]
                [ toastView model
                , headerView model
                , profileView model
                , div [ class "content" ]
                    [ kanbanBoard model ]
                , editorView model
                , detailView model
                ]


authView : Model -> Html Msg
authView model =
    div [ class "auth-page" ]
        [ toastView model
        , div [ class "auth-card" ]
            [ div [ class "auth-brand" ]
                [ div [ class "brand-mark" ] [ text "GS" ]
                , div [] [ span [ class "eyebrow" ] [ text "GENERAL SERVICE" ], h1 [] [ text "업무 관리" ] ]
                ]
            , h2 []
                [ text
                    (if model.authMode == SignIn then
                        "다시 만나서 반갑습니다"

                     else
                        "계정을 만들어 시작하세요"
                    )
                ]
            , p [ class "auth-copy" ] [ text "업무 보드를 사용하려면 로그인해 주세요." ]
            , div [ class "auth-tabs" ]
                [ button [ class (authTabClass (model.authMode == SignIn)), type_ "button", onClick (SelectAuthMode SignIn) ] [ text "로그인" ]
                , button [ class (authTabClass (model.authMode == SignUp)), type_ "button", onClick (SelectAuthMode SignUp) ] [ text "회원가입" ]
                ]
            , div [ class "auth-fields" ]
                ([ div [ class "field" ]
                    [ label [ for "auth-email" ] [ text "이메일" ]
                    , input [ id "auth-email", type_ "email", value model.authEmail, placeholder "name@example.com", onInput EditAuthEmail ] []
                    ]
                 ]
                    ++ (if model.authMode == SignUp then
                            [ div [ class "field" ]
                                [ label [ for "auth-display-name" ] [ text "표시 이름" ]
                                , input [ id "auth-display-name", value model.authDisplayName, placeholder "보드에 표시할 이름", onInput EditAuthDisplayName ] []
                                ]
                            ]

                        else
                            []
                       )
                    ++ [ div [ class "field" ]
                            [ label [ for "auth-password" ] [ text "비밀번호" ]
                            , input [ id "auth-password", type_ "password", value model.authPassword, placeholder "8자 이상", onInput EditAuthPassword ] []
                            ]
                       ]
                )
            , button [ class "button primary auth-submit", type_ "button", disabled model.loading, onClick SubmitAuthentication ]
                [ text
                    (if model.authMode == SignIn then
                        "로그인"

                     else
                        "회원가입하고 시작하기"
                    )
                ]
            , p [ class "auth-footnote" ] [ text "개발용 계정은 이 서버가 실행되는 동안에만 유지됩니다." ]
            ]
        ]


authTabClass : Bool -> String
authTabClass active =
    "auth-tab"
        ++ (if active then
                " is-active"

            else
                ""
           )


headerView : Model -> Html Msg
headerView model =
    div [ class "hero" ]
        [ div [ class "brand-row" ]
            [ div [ class "brand-mark" ] [ text "GS" ]
            , div [] [ span [ class "eyebrow" ] [ text "GENERAL SERVICE" ], h1 [] [ text "업무 관리" ] ]
            , case model.session of
                Just session ->
                    div [ class "user-actions" ]
                        [ button [ class "profile-button", type_ "button", onClick ToggleProfile ] [ text session.user.displayName ]
                        , button [ class "logout-button", type_ "button", onClick LogoutRequested ] [ text "로그아웃" ]
                        ]

                Nothing ->
                    text ""
            ]
        , p [ class "hero-copy" ] [ text "업무의 흐름을 한눈에 보고, 다음 단계로 자연스럽게 이어가세요." ]
        ]


profileView : Model -> Html Msg
profileView model =
    case ( model.profileOpen, model.session ) of
        ( True, Just session ) ->
            div [ class "profile-layer" ]
                [ div [ class "profile-backdrop", onClick ToggleProfile ] []
                , aside [ class "profile-panel", attribute "role" "dialog", attribute "aria-modal" "true", attribute "aria-label" "내 프로필" ]
                    [ div [ class "detail-heading" ]
                        [ div [] [ h2 [] [ text "내 프로필" ], p [ class "profile-email" ] [ text session.user.email ] ]
                        , button [ class "icon-button", type_ "button", attribute "aria-label" "닫기", onClick ToggleProfile ] [ text "×" ]
                        ]
                    , div [ class "field" ]
                        [ label [ for "profile-display-name" ] [ text "표시 이름" ]
                        , input [ id "profile-display-name", value model.profileDraft, onInput EditProfileName ] []
                        ]
                    , div [ class "detail-actions" ]
                        [ button [ class "button secondary", type_ "button", onClick ToggleProfile ] [ text "취소" ]
                        , button [ class "button primary", type_ "button", disabled model.loading, onClick SaveProfile ] [ text "저장" ]
                        ]
                    ]
                ]

        _ ->
            text ""


toastView : Model -> Html Msg
toastView model =
    case model.notice of
        Just notice ->
            div [ class "notice", attribute "aria-live" "polite", attribute "role" "status" ] [ text notice ]

        Nothing ->
            text ""


editorView : Model -> Html Msg
editorView model =
    if model.editorOpen then
        div [ class "detail-layer editor-layer" ]
            [ div [ class "detail-backdrop", onClick CloseEditor ] []
            , aside
                [ class "detail-panel editor-panel"
                , attribute "role" "dialog"
                , attribute "aria-modal" "true"
                , attribute "aria-label"
                    (if model.editing /= Nothing then
                        "업무 수정"

                     else
                        "새 업무 등록"
                    )
                ]
                [ formView model ]
            ]

    else
        text ""


formView : Model -> Html Msg
formView model =
    let
        isEditing =
            model.editing /= Nothing
    in
    div [ class "card editor" ]
        [ div [ class "section-heading" ]
            [ div []
                [ h2 []
                    [ text
                        (if isEditing then
                            "업무 수정"

                         else
                            "새 업무 등록"
                        )
                    ]
                , span []
                    [ text
                        (if isEditing then
                            "변경 내용을 저장하세요"

                         else
                            "업무를 흐름에 추가하세요"
                        )
                    ]
                ]
            , button [ class "icon-button", type_ "button", attribute "aria-label" "닫기", onClick CloseEditor ] [ text "×" ]
            ]
        , div [ class "form-grid" ]
            [ radioField
                "urgency"
                "긴급도"
                model.draft.urgency
                [ ( Task.Urgent, "긴급" ), ( Task.NotUrgent, "긴급하지 않음" ) ]
                Task.urgencyString
                EditUrgency
            , radioField
                "importance"
                "중요도"
                model.draft.importance
                [ ( Task.Important, "중요" ), ( Task.NotImportant, "중요하지 않음" ) ]
                Task.importanceString
                EditImportance
            , div
                [ class
                    ("field title-field"
                        ++ (if isEditing then
                                ""

                            else
                                " full-width"
                           )
                    )
                ]
                [ label [ for "title" ] [ text "업무 제목" ]
                , input [ id "title", value model.draft.title, placeholder "예: 2026년 4분기 계약 갱신", onInput EditTitle ] []
                ]
            , if isEditing then
                div [ class "field" ]
                    [ label [ for "status" ] [ text "현재 상태" ]
                    , select [ id "status", onInput EditStatus ] (List.map (statusOption model.draft.status) Task.allStatuses)
                    ]

              else
                text ""
            , div [ class "field description-field" ]
                [ label [ for "expected-result" ] [ text "기대 결과물" ]
                , textarea [ id "expected-result", value model.draft.expectedResult, placeholder "Outcome Owner가 원하는 결과물을 정의하세요.", onInput EditExpectedResult ] []
                ]
            , div [ class "field description-field" ]
                [ label [ for "description" ] [ text "설명" ]
                , textarea [ id "description", value model.draft.description, placeholder "관리자 메모 또는 업무의 다음 단계를 적어주세요.", onInput EditDescription ] []
                ]
            , div [ class "field" ]
                [ label [ for "task-owner" ] [ text "Task Owner" ]
                , input [ id "task-owner", value model.draft.taskOwner, placeholder "결과물을 제출할 담당자", onInput EditTaskOwner ] []
                ]
            , div [ class "field" ]
                [ label [ for "outcome-owner" ] [ text "Outcome Owner" ]
                , input [ id "outcome-owner", value model.draft.outcomeOwner, placeholder "결과물을 리뷰·승인할 담당자", onInput EditOutcomeOwner ] []
                ]
            ]
        , div [ class "actions" ]
            [ if isEditing then
                button [ class "button secondary", type_ "button", onClick CancelEdit ] [ text "취소" ]

              else
                text ""
            , button [ class "button primary", type_ "button", disabled model.loading, onClick SubmitTask ]
                [ text
                    (if isEditing then
                        "변경 저장"

                     else
                        "업무 등록"
                    )
                ]
            ]
        ]


radioField fieldName fieldLabel selectedValue choices toString toMessage =
    div [ class "field radio-field" ]
        [ span [ class "radio-label" ] [ text fieldLabel ]
        , div [ class "radio-group", attribute "role" "radiogroup", attribute "aria-label" fieldLabel ]
            (List.map
                (\( choice, choiceLabel ) ->
                    label [ class "radio-option" ]
                        [ input
                            [ type_ "radio"
                            , name fieldName
                            , value (toString choice)
                            , checked (selectedValue == choice)
                            , onClick (toMessage (toString choice))
                            ]
                            []
                        , span [] [ text choiceLabel ]
                        ]
                )
                choices
            )
        ]


kanbanBoard : Model -> Html Msg
kanbanBoard model =
    div [ class "kanban-section" ]
        [ div [ class "board-heading" ]
            [ div []
                [ h2 [] [ text "업무 보드" ]
                , p [] [ text "실행 분류에서 업무를 찾고, 아래 상태 스윔레인에서 진행 단계를 관리하세요." ]
                ]
            , div [ class "board-actions" ]
                [ span [ class "board-total" ] [ text (String.fromInt (List.length model.tasks) ++ "개 업무") ]
                , button [ class "button primary new-task-button", type_ "button", onClick OpenNewTask ] [ text "새 업무 등록" ]
                ]
            ]
        , prioritySummary model.tasks
        , div [ class "swimlane-heading" ]
            [ h3 [] [ text "진행 상태 스윔레인" ]
            , p [] [ text "카드를 원하는 상태로 끌어 옮겨 도메인 진행 상태를 변경하세요." ]
            ]
        , if model.loading && List.isEmpty model.tasks then
            p [ class "empty board-empty" ] [ text "업무를 불러오는 중입니다…" ]

          else
            div [ class "kanban-board" ] (List.map (kanbanColumn model) Task.allStatuses)
        ]


kanbanColumn : Model -> Status -> Html Msg
kanbanColumn model taskStatus =
    let
        statusTasks =
            List.filter (\task -> task.status == taskStatus) model.tasks

        dropTargetClass =
            if model.dropTarget == Just taskStatus then
                " is-drop-target"

            else
                ""
    in
    div
        [ class ("kanban-column " ++ Task.statusClass taskStatus ++ dropTargetClass)
        , preventDefaultOn "dragover" (Decode.succeed ( DragOver taskStatus, True ))
        , preventDefaultOn "drop" (Decode.succeed ( DroppedOn taskStatus, True ))
        ]
        [ div [ class "column-heading" ]
            [ span [ class "column-title" ] [ text (Task.statusLabel taskStatus) ]
            , span [ class "column-count" ] [ text (String.fromInt (List.length statusTasks)) ]
            ]
        , div [ class "kanban-cards" ]
            (if List.isEmpty statusTasks then
                [ div [ class "column-empty" ] [ text "등록된 업무가 없습니다" ] ]

             else
                List.map (taskCard model) statusTasks
            )
        ]


taskCard : Model -> Task -> Html Msg
taskCard model task =
    div
        [ class
            ("task-card"
                ++ (if model.draggedTaskId == Just task.taskId then
                        " is-dragging"

                    else
                        ""
                   )
                ++ (if model.selectedTaskId == Just task.taskId then
                        " is-selected"

                    else
                        ""
                   )
            )
        , attribute "draggable"
            (if model.loading then
                "false"

             else
                "true"
            )
        , on "dragstart" (Decode.succeed (DragStarted task.taskId))
        , on "dragend" (Decode.succeed DragEnded)
        ]
        [ h2
            [ class "card-title"
            , attribute "role" "button"
            , tabindex 0
            , onClick (OpenTask task.taskId)
            , onEnterKey (OpenTask task.taskId)
            ]
            [ text task.title ]
        , div [ class "badge-row" ]
            [ span [ class ("priority-badge " ++ Task.quadrantClass (Task.quadrantOf task.urgency task.importance)) ]
                [ text (Task.quadrantLabel (Task.quadrantOf task.urgency task.importance)) ]
            , span [ class "result-chip" ] [ text (Task.resultStateLabel task) ]
            ]
        , p [ class "task-summary" ]
            [ text
                (if task.description == "" then
                    "등록된 설명이 없습니다."

                 else
                    task.description
                )
            ]
        , p [ class "card-owner" ]
            [ span [ class "card-owner-label" ] [ text "Task Owner" ]
            , text task.taskOwner
            ]
        , div [ class "card-footer" ]
            [ span [ class "task-id" ] [ text ("업무 #" ++ String.fromInt task.taskId) ]
            , div [ class "row-actions" ]
                [ button [ class "text-button", type_ "button", onClick (OpenTask task.taskId) ] [ text "상세 보기" ]
                ]
            ]
        ]


onEnterKey : Msg -> Html.Attribute Msg
onEnterKey message =
    on "keydown"
        (Decode.field "key" Decode.string
            |> Decode.andThen
                (\key ->
                    if key == "Enter" || key == " " then
                        Decode.succeed message

                    else
                        Decode.fail "ignored"
                )
        )


detailView : Model -> Html Msg
detailView model =
    case selectedTask model of
        Nothing ->
            text ""

        Just task ->
            div [ class "detail-layer" ]
                [ div [ class "detail-backdrop", onClick CloseTask ] []
                , aside
                    [ class "detail-panel"
                    , attribute "role" "dialog"
                    , attribute "aria-modal" "true"
                    , attribute "aria-label" ("업무 상세: " ++ task.title)
                    ]
                    [ div [ class "detail-heading" ]
                        [ div []
                            [ span [ class ("status-chip " ++ Task.statusClass task.status) ] [ text (Task.statusLabel task.status) ]
                            , h2 [] [ text task.title ]
                            , span [ class "task-id" ] [ text ("업무 #" ++ String.fromInt task.taskId) ]
                            ]
                        , button [ class "icon-button", type_ "button", attribute "aria-label" "닫기", onClick CloseTask ] [ text "×" ]
                        ]
                    , div [ class "badge-row" ]
                        [ span [ class ("priority-badge " ++ Task.quadrantClass (Task.quadrantOf task.urgency task.importance)) ]
                            [ text (Task.quadrantLabel (Task.quadrantOf task.urgency task.importance)) ]
                        , span [ class "result-chip" ] [ text (Task.resultStateLabel task) ]
                        ]
                    , dl [ class "detail-grid" ]
                        [ dt [] [ text "실행 분류" ]
                        , dd [] [ text (Task.quadrantLabel (Task.quadrantOf task.urgency task.importance)) ]
                        , dt [] [ text "진행 상태" ]
                        , dd [] [ text (Task.statusLabel task.status) ]
                        , dt [] [ text "긴급도" ]
                        , dd [] [ text (Task.urgencyLabel task.urgency) ]
                        , dt [] [ text "중요도" ]
                        , dd [] [ text (Task.importanceLabel task.importance) ]
                        , dt [] [ text "Task Owner" ]
                        , dd [] [ text task.taskOwner ]
                        , dt [] [ text "Outcome Owner" ]
                        , dd [] [ text task.outcomeOwner ]
                        ]
                    , detailSection "설명" (nonEmpty "등록된 설명이 없습니다." task.description)
                    , detailSection "기대 결과물" (nonEmpty "기대 결과물이 정의되지 않았습니다." task.expectedResult)
                    , detailSection "제출 결과물" (Maybe.withDefault "아직 제출되지 않았습니다." task.submittedResult)
                    , detailSection "리뷰 코멘트" (Maybe.withDefault "아직 리뷰 코멘트가 없습니다." task.reviewComment)
                    , workflowSection model task
                    , div [ class "detail-actions" ]
                        [ button [ class "button secondary", type_ "button", disabled model.loading, onClick (StartEdit task) ] [ text "수정" ]
                        , button [ class "button danger", type_ "button", disabled model.loading, onClick (DeleteRequested task.taskId) ] [ text "삭제" ]
                        , button [ class "button primary", type_ "button", onClick CloseTask ] [ text "닫기" ]
                        ]
                    ]
                ]


detailSection : String -> String -> Html Msg
detailSection heading body =
    div [ class "detail-section" ]
        [ h3 [] [ text heading ]
        , p [ class "detail-text" ] [ text body ]
        ]


nonEmpty : String -> String -> String
nonEmpty fallback raw =
    if String.trim raw == "" then
        fallback

    else
        raw


workflowSection : Model -> Task -> Html Msg
workflowSection model task =
    if Task.canSubmitResult task then
        div [ class "detail-section workflow-section" ]
            [ h3 [] [ text "결과물 제출" ]
            , p [ class "workflow-hint" ] [ text ("Task Owner " ++ task.taskOwner ++ " 명의로 제출합니다. 제출하면 업무가 제출됨 상태로 이동합니다.") ]
            , textarea
                [ id "submission"
                , value model.submissionDraft
                , placeholder "기대 결과물에 맞춰 완료한 결과물을 적어 주세요."
                , onInput EditSubmission
                ]
                []
            , div [ class "workflow-actions" ]
                [ button [ class "button primary", type_ "button", disabled model.loading, onClick (SubmitResult task.taskId) ] [ text "결과물 제출" ] ]
            ]

    else if Task.canReviewResult task then
        div [ class "detail-section workflow-section" ]
            [ h3 [] [ text "결과물 리뷰" ]
            , p [ class "workflow-hint" ] [ text ("Outcome Owner " ++ task.outcomeOwner ++ " 명의로 처리합니다. 승인하면 승인됨, 수정 요청하면 검토 완료 상태로 이동합니다.") ]
            , textarea
                [ id "review-comment"
                , value model.reviewDraft
                , placeholder "리뷰 코멘트 (선택)"
                , onInput EditReviewComment
                ]
                []
            , div [ class "workflow-actions" ]
                [ button [ class "button secondary", type_ "button", disabled model.loading, onClick (RequestRevision task.taskId) ] [ text "수정 요청" ]
                , button [ class "button primary", type_ "button", disabled model.loading, onClick (ApproveResult task.taskId) ] [ text "승인" ]
                ]
            ]

    else
        div [ class "detail-section workflow-section" ]
            [ h3 [] [ text "다음 단계" ]
            , p [ class "workflow-hint" ]
                [ text
                    (case task.status of
                        Task.Submitted ->
                            "제출된 결과물이 없어 리뷰할 수 없습니다. 초안 또는 검토 완료 컬럼으로 되돌린 뒤 결과물을 제출해 주세요."

                        Task.Approved ->
                            "승인이 완료되었습니다. 이 결과물은 Outcome에 반영할 수 있습니다."

                        Task.Effective ->
                            "효력이 발생한 업무입니다."

                        _ ->
                            "진행할 수 있는 동작이 없습니다."
                    )
                ]
            ]


statusOption : Status -> Status -> Html Msg
statusOption selectedStatus current =
    option [ value (Task.statusString current), selected (selectedStatus == current) ] [ text (Task.statusLabel current) ]


urgencyOption : Urgency -> Urgency -> Html Msg
urgencyOption selectedUrgency current =
    option [ value (Task.urgencyString current), selected (selectedUrgency == current) ] [ text (Task.urgencyLabel current) ]


importanceOption : Importance -> Importance -> Html Msg
importanceOption selectedImportance current =
    option [ value (Task.importanceString current), selected (selectedImportance == current) ] [ text (Task.importanceLabel current) ]


prioritySummary : List Task -> Html Msg
prioritySummary tasks =
    let
        summaryItem quadrant =
            let
                quadrantTasks =
                    Task.tasksInQuadrant quadrant tasks
            in
            div [ class ("priority-summary-item " ++ Task.quadrantClass quadrant) ]
                [ div [ class "priority-summary-heading" ]
                    [ span [ class "priority-summary-label" ] [ text (Task.quadrantLabel quadrant) ]
                    , span [ class "priority-summary-count" ] [ text (String.fromInt (List.length quadrantTasks)) ]
                    ]
                , div [ class "priority-task-list" ]
                    (if List.isEmpty quadrantTasks then
                        [ p [ class "priority-empty" ] [ text "배치된 업무가 없습니다" ] ]

                     else
                        List.map priorityTaskCard quadrantTasks
                    )
                ]
    in
    div [ class "priority-summary", attribute "aria-label" "아이젠하워 매트릭스 실행 분류별 업무" ]
        [ summaryItem Task.DoFirst
        , summaryItem Task.Schedule
        , summaryItem Task.Delegate
        , summaryItem Task.Eliminate
        ]


priorityTaskCard : Task -> Html Msg
priorityTaskCard task =
    button
        [ class "priority-task-card"
        , type_ "button"
        , onClick (OpenTask task.taskId)
        , attribute "aria-label" (task.title ++ " 상세 보기")
        ]
        [ span [ class "priority-task-title" ] [ text task.title ]
        , span [ class "priority-task-meta" ]
            [ text ("Task Owner " ++ task.taskOwner ++ " · " ++ Task.statusLabel task.status) ]
        , span [ class "priority-task-result" ] [ text (Task.resultStateLabel task) ]
        , span [ class "priority-task-description" ]
            [ text (nonEmpty "등록된 설명이 없습니다." task.description) ]
        ]
