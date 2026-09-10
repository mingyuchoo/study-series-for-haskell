module Application.TaskBoard exposing
    ( ApiError(..)
    , AuthMode(..)
    , Effect(..)
    , Model
    , Msg(..)
    , Profile
    , Session
    , init
    , initialModel
    , selectedTask
    , update
    )

import Domain.Task as Task exposing (Task, TaskInput)


type alias Model =
    { tasks : List Task
    , draft : TaskInput
    , editing : Maybe Task
    , draggedTaskId : Maybe Int
    , dropTarget : Maybe Task.Status
    , selectedTaskId : Maybe Int
    , submissionDraft : String
    , reviewDraft : String
    , loading : Bool
    , notice : Maybe String
    , noticeVersion : Int
    , authMode : AuthMode
    , authEmail : String
    , authDisplayName : String
    , authPassword : String
    , session : Maybe Session
    , profileOpen : Bool
    , profileDraft : String
    , editorOpen : Bool
    }


type AuthMode
    = SignIn
    | SignUp


type alias Profile =
    { id : Int
    , email : String
    , displayName : String
    }


type alias Session =
    { token : String
    , user : Profile
    }


type ApiError
    = RequestFailed
    | Rejected String


type Effect
    = LoadTasks
    | CreateTask TaskInput
    | UpdateTask Int TaskInput
    | MoveTask Int TaskInput
    | DeleteTask Int
    | SubmitTaskResult Int String String
    | ApproveTaskResult Int String (Maybe String)
    | RequestTaskRevision Int String (Maybe String)
    | Register String String String
    | Login String String
    | UpdateProfile String String
    | Logout String
    | ClearNoticeAfter Int


type Msg
    = GotTasks (Result ApiError (List Task))
    | SelectAuthMode AuthMode
    | EditAuthEmail String
    | EditAuthDisplayName String
    | EditAuthPassword String
    | SubmitAuthentication
    | Authenticated (Result ApiError Session)
    | ToggleProfile
    | EditProfileName String
    | SaveProfile
    | ProfileSaved (Result ApiError Profile)
    | LogoutRequested
    | LoggedOut (Result ApiError ())
    | EditTitle String
    | EditDescription String
    | EditStatus String
    | EditUrgency String
    | EditImportance String
    | EditTaskOwner String
    | EditOutcomeOwner String
    | EditExpectedResult String
    | OpenNewTask
    | CloseEditor
    | SubmitTask
    | StartEdit Task
    | CancelEdit
    | DeleteRequested Int
    | Saved (Result ApiError Task)
    | Deleted (Result ApiError ())
    | DragStarted Int
    | DragOver Task.Status
    | DragEnded
    | DroppedOn Task.Status
    | MoveSaved (Result ApiError Task)
    | OpenTask Int
    | CloseTask
    | EditSubmission String
    | EditReviewComment String
    | SubmitResult Int
    | ApproveResult Int
    | RequestRevision Int
    | WorkflowSaved (Result ApiError Task)
    | DismissNotice Int


initialModel : Model
initialModel =
    { tasks = []
    , draft = Task.emptyInput
    , editing = Nothing
    , draggedTaskId = Nothing
    , dropTarget = Nothing
    , selectedTaskId = Nothing
    , submissionDraft = ""
    , reviewDraft = ""
    , loading = False
    , notice = Nothing
    , noticeVersion = 0
    , authMode = SignIn
    , authEmail = ""
    , authDisplayName = ""
    , authPassword = ""
    , session = Nothing
    , profileOpen = False
    , profileDraft = ""
    , editorOpen = False
    }


init : ( Model, List Effect )
init =
    ( initialModel, [] )


{-| 상세 패널에 표시할 업무. 선택된 ID가 목록에 없으면 Nothing이다.
-}
selectedTask : Model -> Maybe Task
selectedTask model =
    model.selectedTaskId |> Maybe.andThen (\taskId -> findTask taskId model)


update : Msg -> Model -> ( Model, List Effect )
update msg model =
    case msg of
        SelectAuthMode mode ->
            ( { model | authMode = mode, notice = Nothing }, [] )

        EditAuthEmail email ->
            ( { model | authEmail = email }, [] )

        EditAuthDisplayName displayName ->
            ( { model | authDisplayName = displayName }, [] )

        EditAuthPassword password ->
            ( { model | authPassword = password }, [] )

        SubmitAuthentication ->
            if String.trim model.authEmail == "" || String.trim model.authPassword == "" then
                showNotice "이메일과 비밀번호를 입력해 주세요." model

            else if model.authMode == SignUp && String.trim model.authDisplayName == "" then
                showNotice "표시 이름을 입력해 주세요." model

            else
                let
                    effect =
                        case model.authMode of
                            SignIn ->
                                Login (String.trim model.authEmail) model.authPassword

                            SignUp ->
                                Register (String.trim model.authEmail) (String.trim model.authDisplayName) model.authPassword
                in
                ( { model | loading = True, notice = Nothing }, [ effect ] )

        Authenticated result ->
            case result of
                Ok session ->
                    ( { model
                        | session = Just session
                        , authPassword = ""
                        , profileDraft = session.user.displayName
                        , loading = True
                      }
                    , [ LoadTasks ]
                    )

                Err error ->
                    showNotice (errorMessage "가입 또는 로그인하지 못했습니다." error) { model | loading = False }

        ToggleProfile ->
            case model.session of
                Just session ->
                    ( { model | profileOpen = not model.profileOpen, profileDraft = session.user.displayName }, [] )

                Nothing ->
                    ( model, [] )

        EditProfileName displayName ->
            ( { model | profileDraft = displayName }, [] )

        SaveProfile ->
            case model.session of
                Just session ->
                    if String.trim model.profileDraft == "" then
                        showNotice "표시 이름을 입력해 주세요." model

                    else
                        ( { model | loading = True, notice = Nothing }, [ UpdateProfile session.token (String.trim model.profileDraft) ] )

                Nothing ->
                    ( model, [] )

        ProfileSaved result ->
            case ( result, model.session ) of
                ( Ok profile, Just session ) ->
                    showNotice "프로필을 저장했습니다."
                        { model | session = Just { session | user = profile }, profileDraft = profile.displayName, profileOpen = False, loading = False }

                ( Err error, _ ) ->
                    showNotice (errorMessage "프로필을 저장하지 못했습니다." error) { model | loading = False }

                _ ->
                    ( model, [] )

        LogoutRequested ->
            case model.session of
                Just session ->
                    ( { model | loading = True, notice = Nothing }, [ Logout session.token ] )

                Nothing ->
                    ( model, [] )

        LoggedOut result ->
            case result of
                Ok _ ->
                    showNotice "로그아웃했습니다." { initialModel | noticeVersion = model.noticeVersion }

                Err error ->
                    showNotice (errorMessage "로그아웃하지 못했습니다." error) { model | loading = False }

        GotTasks result ->
            case result of
                Ok tasks ->
                    let
                        stillSelected =
                            model.selectedTaskId
                                |> Maybe.andThen
                                    (\taskId ->
                                        if List.any (\task -> task.taskId == taskId) tasks then
                                            Just taskId

                                        else
                                            Nothing
                                    )
                    in
                    ( { model | tasks = tasks, loading = False, selectedTaskId = stillSelected }, [] )

                Err error ->
                    showNotice (errorMessage "업무 목록을 불러오지 못했습니다." error) { model | loading = False }

        EditTitle title ->
            ( updateForm (\form -> { form | title = title }) model, [] )

        EditDescription description ->
            ( updateForm (\form -> { form | description = description }) model, [] )

        EditStatus rawStatus ->
            case Task.statusFromString rawStatus of
                Just taskStatus ->
                    ( updateForm (\form -> { form | status = taskStatus }) model, [] )

                Nothing ->
                    showNotice "알 수 없는 업무 상태입니다." model

        EditUrgency rawUrgency ->
            case Task.urgencyFromString rawUrgency of
                Just taskUrgency ->
                    ( updateForm (\form -> { form | urgency = taskUrgency }) model, [] )

                Nothing ->
                    showNotice "알 수 없는 긴급도입니다." model

        EditImportance rawImportance ->
            case Task.importanceFromString rawImportance of
                Just taskImportance ->
                    ( updateForm (\form -> { form | importance = taskImportance }) model, [] )

                Nothing ->
                    showNotice "알 수 없는 중요도입니다." model

        EditTaskOwner owner ->
            ( updateForm (\form -> { form | taskOwner = owner }) model, [] )

        EditOutcomeOwner owner ->
            ( updateForm (\form -> { form | outcomeOwner = owner }) model, [] )

        EditExpectedResult expected ->
            ( updateForm (\form -> { form | expectedResult = expected }) model, [] )

        OpenNewTask ->
            ( { model | editorOpen = True, editing = Nothing, draft = Task.emptyInput, notice = Nothing }, [] )

        CloseEditor ->
            ( closeEditor model, [] )

        SubmitTask ->
            case Task.validateInput model.draft of
                Err Task.TitleRequired ->
                    showNotice "업무 제목을 입력해 주세요." model

                Ok input ->
                    case model.editing of
                        Just task ->
                            ( { model | loading = True, notice = Nothing }, [ UpdateTask task.taskId input ] )

                        Nothing ->
                            ( { model | loading = True, notice = Nothing }
                            , [ CreateTask { input | status = Task.Draft } ]
                            )

        StartEdit task ->
            ( { model | editing = Just task, draft = toInput task, editorOpen = True, notice = Nothing } |> closePanel, [] )

        CancelEdit ->
            ( closeEditor model, [] )

        DeleteRequested taskId ->
            ( { model | loading = True, notice = Nothing } |> closePanel, [ DeleteTask taskId ] )

        Saved result ->
            case result of
                Ok _ ->
                    showNotice "업무가 저장되었습니다." (closeEditor model)
                        |> addEffect LoadTasks

                Err error ->
                    showNotice (errorMessage "저장하지 못했습니다. 다시 시도해 주세요." error) { model | loading = False }

        Deleted result ->
            case result of
                Ok _ ->
                    showNotice "업무를 삭제했습니다." model
                        |> addEffect LoadTasks

                Err error ->
                    showNotice (errorMessage "업무를 삭제하지 못했습니다." error) { model | loading = False }

        DragStarted taskId ->
            if model.loading then
                ( model, [] )

            else
                ( { model | draggedTaskId = Just taskId, dropTarget = Nothing, notice = Nothing }, [] )

        DragOver taskStatus ->
            case model.draggedTaskId of
                Just _ ->
                    ( { model | dropTarget = Just taskStatus }, [] )

                Nothing ->
                    ( model, [] )

        DragEnded ->
            ( { model | draggedTaskId = Nothing, dropTarget = Nothing }, [] )

        DroppedOn targetStatus ->
            case ( model.loading, model.draggedTaskId ) of
                ( False, Just taskId ) ->
                    case findTask taskId model of
                        Just task ->
                            if task.status == targetStatus then
                                ( { model | draggedTaskId = Nothing, dropTarget = Nothing }, [] )

                            else
                                ( { model | loading = True, draggedTaskId = Nothing, dropTarget = Nothing, notice = Nothing }
                                , [ MoveTask taskId { title = task.title, description = task.description, status = targetStatus, urgency = task.urgency, importance = task.importance, taskOwner = task.taskOwner, outcomeOwner = task.outcomeOwner, expectedResult = task.expectedResult } ]
                                )

                        Nothing ->
                            ( { model | draggedTaskId = Nothing, dropTarget = Nothing }, [] )

                _ ->
                    ( model, [] )

        MoveSaved result ->
            case result of
                Ok movedTask ->
                    showNotice
                        ("업무 상태를 " ++ Task.statusLabel movedTask.status ++ " 상태로 변경했습니다.")
                        { model | tasks = List.map (replaceTask movedTask) model.tasks, loading = False }

                Err error ->
                    showNotice (errorMessage "상태를 변경하지 못했습니다. 다시 시도해 주세요." error) { model | loading = False }

        OpenTask taskId ->
            case findTask taskId model of
                Just task ->
                    ( { model
                        | selectedTaskId = Just taskId
                        , submissionDraft = Maybe.withDefault "" task.submittedResult
                        , reviewDraft = ""
                      }
                    , []
                    )

                Nothing ->
                    ( model, [] )

        CloseTask ->
            ( closePanel model, [] )

        EditSubmission submission ->
            ( { model | submissionDraft = submission }, [] )

        EditReviewComment comment ->
            ( { model | reviewDraft = comment }, [] )

        SubmitResult taskId ->
            case findTask taskId model of
                Just task ->
                    if String.trim model.submissionDraft == "" then
                        showNotice "제출 결과물을 입력해 주세요." model

                    else
                        ( { model | loading = True, notice = Nothing }
                        , [ SubmitTaskResult taskId task.taskOwner (String.trim model.submissionDraft) ]
                        )

                Nothing ->
                    ( model, [] )

        ApproveResult taskId ->
            case findTask taskId model of
                Just task ->
                    ( { model | loading = True, notice = Nothing }
                    , [ ApproveTaskResult taskId task.outcomeOwner (optionalText model.reviewDraft) ]
                    )

                Nothing ->
                    ( model, [] )

        RequestRevision taskId ->
            case findTask taskId model of
                Just task ->
                    ( { model | loading = True, notice = Nothing }
                    , [ RequestTaskRevision taskId task.outcomeOwner (optionalText model.reviewDraft) ]
                    )

                Nothing ->
                    ( model, [] )

        WorkflowSaved result ->
            case result of
                Ok task ->
                    showNotice (workflowNotice task)
                        { model
                            | tasks = List.map (replaceTask task) model.tasks
                            , loading = False
                            , submissionDraft = Maybe.withDefault "" task.submittedResult
                            , reviewDraft = ""
                        }

                Err error ->
                    showNotice (errorMessage "처리하지 못했습니다. 다시 시도해 주세요." error) { model | loading = False }

        DismissNotice version ->
            if model.noticeVersion == version then
                ( { model | notice = Nothing }, [] )

            else
                ( model, [] )


updateForm : (TaskInput -> TaskInput) -> Model -> Model
updateForm transform model =
    { model | draft = transform model.draft }


closePanel : Model -> Model
closePanel model =
    { model | selectedTaskId = Nothing, submissionDraft = "", reviewDraft = "" }


closeEditor : Model -> Model
closeEditor model =
    { model | editorOpen = False, editing = Nothing, draft = Task.emptyInput }


findTask : Int -> Model -> Maybe Task
findTask taskId model =
    List.filter (\task -> task.taskId == taskId) model.tasks |> List.head


optionalText : String -> Maybe String
optionalText raw =
    if String.trim raw == "" then
        Nothing

    else
        Just (String.trim raw)


workflowNotice : Task -> String
workflowNotice task =
    case task.status of
        Task.Submitted ->
            "결과물을 제출했습니다."

        Task.Approved ->
            "결과물을 승인했습니다."

        Task.Reviewed ->
            "수정을 요청했습니다."

        _ ->
            "업무를 갱신했습니다."


errorMessage : String -> ApiError -> String
errorMessage fallback error =
    case error of
        Rejected message ->
            message

        RequestFailed ->
            fallback


toInput : Task -> TaskInput
toInput task =
    { title = task.title, description = task.description, status = task.status, urgency = task.urgency, importance = task.importance, taskOwner = task.taskOwner, outcomeOwner = task.outcomeOwner, expectedResult = task.expectedResult }


replaceTask : Task -> Task -> Task
replaceTask movedTask currentTask =
    if currentTask.taskId == movedTask.taskId then
        movedTask

    else
        currentTask


showNotice : String -> Model -> ( Model, List Effect )
showNotice message model =
    let
        nextVersion =
            model.noticeVersion + 1
    in
    ( { model | notice = Just message, noticeVersion = nextVersion }, [ ClearNoticeAfter nextVersion ] )


addEffect : Effect -> ( Model, List Effect ) -> ( Model, List Effect )
addEffect effect ( model, effects ) =
    ( model, effect :: effects )
