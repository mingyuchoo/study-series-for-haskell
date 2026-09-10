module MainTest exposing (suite)

import Application.TaskBoard as TaskBoard
import Domain.Task as Task
import Expect
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "업무 상태"
        [ test "상태를 한국어 레이블로 표시한다" <|
            \_ ->
                Expect.equal
                    [ "초안", "검토 완료", "제출됨", "승인됨", "효력 발생" ]
                    (List.map Task.statusLabel Task.allStatuses)
        , test "긴급도와 중요도를 아이젠하워 사분면으로 변환한다" <|
            \_ ->
                Expect.equal
                    [ Task.DoFirst, Task.Schedule, Task.Delegate, Task.Eliminate ]
                    [ Task.quadrantOf Task.Urgent Task.Important
                    , Task.quadrantOf Task.NotUrgent Task.Important
                    , Task.quadrantOf Task.Urgent Task.NotImportant
                    , Task.quadrantOf Task.NotUrgent Task.NotImportant
                    ]
        , test "실행 분류별로 해당 Task만 찾는다" <|
            \_ ->
                let
                    scheduleTask =
                        { sampleTask | taskId = 2, urgency = Task.NotUrgent, importance = Task.Important }

                    delegateTask =
                        { sampleTask | taskId = 3, urgency = Task.Urgent, importance = Task.NotImportant }
                in
                Expect.equal
                    [ 2 ]
                    (Task.tasksInQuadrant Task.Schedule [ sampleTask, scheduleTask, delegateTask ]
                        |> List.map .taskId
                    )
        , test "초기 인증 화면에서 회원가입 버튼을 사용할 수 있다" <|
            \_ ->
                let
                    baseModel =
                        TaskBoard.initialModel

                    model =
                        { baseModel
                            | authMode = TaskBoard.SignUp
                            , authEmail = "member@example.com"
                            , authDisplayName = "새 사용자"
                            , authPassword = "safe-password"
                        }

                    ( updatedModel, effects ) =
                        TaskBoard.update TaskBoard.SubmitAuthentication model
                in
                Expect.equal
                    ( True, [ TaskBoard.Register "member@example.com" "새 사용자" "safe-password" ] )
                    ( updatedModel.loading, effects )
        , test "빈 제목 제출은 효과 없이 사용자에게 알린다" <|
            \_ ->
                case TaskBoard.update TaskBoard.SubmitTask TaskBoard.initialModel of
                    ( model, effects ) ->
                        Expect.equal
                            ( Just "업무 제목을 입력해 주세요.", [ TaskBoard.ClearNoticeAfter 1 ] )
                            ( model.notice, effects )
        , test "새 업무 등록을 열고 닫으면 입력 상태를 초기화한다" <|
            \_ ->
                let
                    baseModel =
                        TaskBoard.initialModel

                    modelWithEditing =
                        { baseModel | editing = Just sampleTask }

                    openedModel =
                        TaskBoard.update TaskBoard.OpenNewTask modelWithEditing
                            |> Tuple.first

                    ( closedModel, effects ) =
                        TaskBoard.update TaskBoard.CloseEditor openedModel
                in
                Expect.equal
                    { opened = True, openedEditing = Nothing, openedDraft = Task.emptyInput, closed = False, closedEditing = Nothing, closedDraft = Task.emptyInput, effects = [] }
                    { opened = openedModel.editorOpen, openedEditing = openedModel.editing, openedDraft = openedModel.draft, closed = closedModel.editorOpen, closedEditing = closedModel.editing, closedDraft = closedModel.draft, effects = effects }
        , test "새 업무는 입력 상태와 관계없이 초안으로 저장한다" <|
            \_ ->
                let
                    baseModel =
                        TaskBoard.initialModel

                    model =
                        { baseModel
                            | loading = False
                            , draft =
                                { title = "신규 계약서 검토"
                                , description = "법무 검토를 위한 초안을 준비했습니다."
                                , status = Task.Effective
                                , urgency = Task.Urgent
                                , importance = Task.Important
                                , taskOwner = "김태스크"
                                , outcomeOwner = "이아웃컴"
                                , expectedResult = "검토 보고서"
                                }
                        }

                    ( updatedModel, effects ) =
                        TaskBoard.update TaskBoard.SubmitTask model
                in
                Expect.equal
                    ( True
                    , [ TaskBoard.CreateTask
                            { title = "신규 계약서 검토"
                            , description = "법무 검토를 위한 초안을 준비했습니다."
                            , status = Task.Draft
                            , urgency = Task.Urgent
                            , importance = Task.Important
                            , taskOwner = "김태스크"
                            , outcomeOwner = "이아웃컴"
                            , expectedResult = "검토 보고서"
                            }
                      ]
                    )
                    ( updatedModel.loading, effects )
        , test "카드를 다른 상태 컬럼에 놓으면 상태 변경 저장을 요청한다" <|
            \_ ->
                let
                    task =
                        { taskId = 1
                        , title = "신규 계약서 검토"
                        , description = "법무 검토를 위한 초안을 준비했습니다."
                        , status = Task.Draft
                        , urgency = Task.Urgent
                        , importance = Task.Important
                        , taskOwner = "김태스크"
                        , outcomeOwner = "이아웃컴"
                        , expectedResult = "검토 보고서"
                        , submittedResult = Nothing
                        , reviewComment = Nothing
                        }

                    baseModel =
                        TaskBoard.initialModel

                    initialDragModel =
                        { baseModel | tasks = [ task ], loading = False }

                    ( draggingModel, _ ) =
                        TaskBoard.update (TaskBoard.DragStarted task.taskId) initialDragModel

                    ( droppedModel, effects ) =
                        TaskBoard.update (TaskBoard.DroppedOn Task.Submitted) draggingModel
                in
                Expect.equal
                    ( True, [ TaskBoard.MoveTask 1 { title = task.title, description = task.description, status = Task.Submitted, urgency = task.urgency, importance = task.importance, taskOwner = task.taskOwner, outcomeOwner = task.outcomeOwner, expectedResult = task.expectedResult } ] )
                    ( droppedModel.loading, effects )
        , test "상태 변경 저장 후에는 받은 업무로 보드를 갱신한다" <|
            \_ ->
                let
                    originalTask =
                        { taskId = 1
                        , title = "신규 계약서 검토"
                        , description = "법무 검토를 위한 초안을 준비했습니다."
                        , status = Task.Draft
                        , urgency = Task.NotUrgent
                        , importance = Task.Important
                        , taskOwner = "김태스크"
                        , outcomeOwner = "이아웃컴"
                        , expectedResult = "검토 보고서"
                        , submittedResult = Nothing
                        , reviewComment = Nothing
                        }

                    movedTask =
                        { originalTask | status = Task.Submitted }

                    baseModel =
                        TaskBoard.initialModel

                    model =
                        { baseModel | tasks = [ originalTask ], loading = True }

                    ( updatedModel, effects ) =
                        TaskBoard.update (TaskBoard.MoveSaved (Ok movedTask)) model
                in
                Expect.equal
                    { tasks = [ movedTask ]
                    , loading = False
                    , notice = Just "업무 상태를 제출됨 상태로 변경했습니다."
                    , noticeVersion = 1
                    , effects = [ TaskBoard.ClearNoticeAfter 1 ]
                    }
                    { tasks = updatedModel.tasks
                    , loading = updatedModel.loading
                    , notice = updatedModel.notice
                    , noticeVersion = updatedModel.noticeVersion
                    , effects = effects
                    }
        , test "결과물 진행 상태를 짧은 레이블로 표시한다" <|
            \_ ->
                Expect.equal
                    [ "결과물 미제출", "리뷰 대기", "수정 요청됨", "승인 완료", "결과물 없음" ]
                    [ Task.resultStateLabel sampleTask
                    , Task.resultStateLabel { sampleTask | status = Task.Submitted, submittedResult = Just "초안" }
                    , Task.resultStateLabel { sampleTask | status = Task.Reviewed, submittedResult = Just "초안", reviewComment = Just "보완 필요" }
                    , Task.resultStateLabel { sampleTask | status = Task.Approved, submittedResult = Just "초안" }
                    , Task.resultStateLabel { sampleTask | status = Task.Submitted }
                    ]
        , test "카드를 열면 상세 패널이 선택되고 기존 제출 결과물이 초안으로 채워진다" <|
            \_ ->
                let
                    task =
                        { sampleTask | submittedResult = Just "이전 제출물" }

                    ( model, effects ) =
                        TaskBoard.update (TaskBoard.OpenTask 1) { boardModel | tasks = [ task ] }
                in
                Expect.equal
                    ( Just task, "이전 제출물", [] )
                    ( TaskBoard.selectedTask model, model.submissionDraft, effects )
        , test "빈 결과물 제출은 효과 없이 사용자에게 알린다" <|
            \_ ->
                let
                    ( model, effects ) =
                        TaskBoard.update (TaskBoard.SubmitResult 1) { boardModel | tasks = [ sampleTask ], selectedTaskId = Just 1, submissionDraft = "   " }
                in
                Expect.equal
                    ( Just "제출 결과물을 입력해 주세요.", False, [ TaskBoard.ClearNoticeAfter 1 ] )
                    ( model.notice, model.loading, effects )
        , test "결과물 제출은 Task Owner 명의로 제출 요청을 보낸다" <|
            \_ ->
                let
                    ( model, effects ) =
                        TaskBoard.update (TaskBoard.SubmitResult 1) { boardModel | tasks = [ sampleTask ], selectedTaskId = Just 1, submissionDraft = " 검토 보고서 v1 " }
                in
                Expect.equal
                    ( True, [ TaskBoard.SubmitTaskResult 1 "김태스크" "검토 보고서 v1" ] )
                    ( model.loading, effects )
        , test "승인과 수정 요청은 Outcome Owner 명의로 보내며 빈 코멘트는 생략한다" <|
            \_ ->
                let
                    submitted =
                        { sampleTask | status = Task.Submitted, submittedResult = Just "검토 보고서 v1" }

                    ( _, approveEffects ) =
                        TaskBoard.update (TaskBoard.ApproveResult 1) { boardModel | tasks = [ submitted ], selectedTaskId = Just 1, reviewDraft = "" }

                    ( _, revisionEffects ) =
                        TaskBoard.update (TaskBoard.RequestRevision 1) { boardModel | tasks = [ submitted ], selectedTaskId = Just 1, reviewDraft = "표를 보완해 주세요." }
                in
                Expect.equal
                    ( [ TaskBoard.ApproveTaskResult 1 "이아웃컴" Nothing ]
                    , [ TaskBoard.RequestTaskRevision 1 "이아웃컴" (Just "표를 보완해 주세요.") ]
                    )
                    ( approveEffects, revisionEffects )
        , test "워크플로 처리 후에는 보드를 갱신하고 패널을 유지한다" <|
            \_ ->
                let
                    approved =
                        { sampleTask | status = Task.Approved, submittedResult = Just "검토 보고서 v1" }

                    ( model, effects ) =
                        TaskBoard.update (TaskBoard.WorkflowSaved (Ok approved)) { boardModel | tasks = [ sampleTask ], selectedTaskId = Just 1, loading = True, reviewDraft = "좋습니다" }
                in
                Expect.equal
                    { tasks = [ approved ], selected = Just approved, notice = Just "결과물을 승인했습니다.", loading = False, reviewDraft = "", effects = [ TaskBoard.ClearNoticeAfter 1 ] }
                    { tasks = model.tasks, selected = TaskBoard.selectedTask model, notice = model.notice, loading = model.loading, reviewDraft = model.reviewDraft, effects = effects }
        , test "서버가 거부한 이유를 그대로 알린다" <|
            \_ ->
                let
                    ( model, _ ) =
                        TaskBoard.update (TaskBoard.WorkflowSaved (Err (TaskBoard.Rejected "Result has not been submitted"))) { boardModel | loading = True }
                in
                Expect.equal ( Just "Result has not been submitted", False ) ( model.notice, model.loading )
        , test "수정을 시작하거나 삭제하면 상세 패널을 닫는다" <|
            \_ ->
                let
                    ( editModel, _ ) =
                        TaskBoard.update (TaskBoard.StartEdit sampleTask) { boardModel | tasks = [ sampleTask ], selectedTaskId = Just 1 }

                    ( deleteModel, deleteEffects ) =
                        TaskBoard.update (TaskBoard.DeleteRequested 1) { boardModel | tasks = [ sampleTask ], selectedTaskId = Just 1 }
                in
                Expect.equal
                    { editSelected = Nothing, editing = Just sampleTask, editorOpen = True, deleteSelected = Nothing, deleteEffects = [ TaskBoard.DeleteTask 1 ] }
                    { editSelected = editModel.selectedTaskId, editing = editModel.editing, editorOpen = editModel.editorOpen, deleteSelected = deleteModel.selectedTaskId, deleteEffects = deleteEffects }
        , test "오래된 타이머는 새 알림을 닫지 않는다" <|
            \_ ->
                let
                    baseModel =
                        TaskBoard.initialModel

                    model =
                        { baseModel | notice = Just "새 알림", noticeVersion = 2 }

                    ( updatedModel, effects ) =
                        TaskBoard.update (TaskBoard.DismissNotice 1) model
                in
                Expect.equal ( Just "새 알림", [] ) ( updatedModel.notice, effects )
        ]


sampleTask : Task.Task
sampleTask =
    { taskId = 1
    , title = "신규 계약서 검토"
    , description = "법무 검토를 위한 초안을 준비했습니다."
    , status = Task.Draft
    , urgency = Task.Urgent
    , importance = Task.Important
    , taskOwner = "김태스크"
    , outcomeOwner = "이아웃컴"
    , expectedResult = "검토 보고서"
    , submittedResult = Nothing
    , reviewComment = Nothing
    }


boardModel : TaskBoard.Model
boardModel =
    let
        base =
            TaskBoard.initialModel
    in
    { base | loading = False }
