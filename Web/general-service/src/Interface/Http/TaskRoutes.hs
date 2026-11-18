{-# LANGUAGE OverloadedStrings #-}

module Interface.Http.TaskRoutes
  ( application
  )
where

import qualified Application.AuthService as AuthService
import Application.Port.TaskRepository (TaskRepository)
import Application.Port.UserRepository (UserRepository)
import qualified Application.TaskService as TaskService
import Data.Aeson
  ( FromJSON (..)
  , ToJSON (..)
  , eitherDecode
  , encode
  , object
  , withObject
  , (.:)
  , (.:?)
  , (.=)
  )
import Data.ByteString (ByteString)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import Domain.Task
  ( Importance (..)
  , Outcome (..)
  , OutcomeInput (..)
  , OutcomeOwner (..)
  , Quadrant (..)
  , Status (..)
  , TaskError (..)
  , TaskInput (..)
  , TaskItem (..)
  , TaskOwner (..)
  , Urgency (..)
  , quadrantOf
  )
import Domain.User
  ( AuthError (..)
  , ProfileUpdate (..)
  , SignUpInput (..)
  , UserProfile (..)
  )
import Network.HTTP.Types
  ( methodDelete
  , methodGet
  , methodPost
  , methodPut
  , status200
  , status201
  , status204
  , status400
  , status401
  , status404
  , status409
  )
import qualified Network.HTTP.Types as HTTP
import Network.Wai
import Text.Read (readMaybe)

data TaskInputRequest
  = TaskInputRequest Text Text Status Urgency Importance TaskOwner OutcomeOwner Text

data TaskResponse
  = TaskResponse
      Int
      Text
      Text
      Status
      Urgency
      Importance
      Quadrant
      TaskOwner
      OutcomeOwner
      Text
      (Maybe Text)
      (Maybe Text)

data SubmissionRequest = SubmissionRequest TaskOwner Text

data ReviewRequest = ReviewRequest OutcomeOwner (Maybe Text)

data OutcomeInputRequest = OutcomeInputRequest Text OutcomeOwner [Int]

data OutcomeResponse = OutcomeResponse Int Text OutcomeOwner [Int] [Text] Status

data SignUpRequest = SignUpRequest Text Text Text

data LoginRequest = LoginRequest Text Text

newtype ProfileUpdateRequest = ProfileUpdateRequest Text

data ProfileResponse = ProfileResponse Int Text Text

data SessionResponse = SessionResponse Text ProfileResponse

instance FromJSON TaskInputRequest where
  parseJSON = withObject "TaskInputRequest" $ \value -> do
    rawStatus <- value .: "status"
    taskStatus <- maybe (fail "Unknown task status") pure (statusFromText rawStatus)
    rawUrgency <- value .: "urgency"
    taskUrgency <- maybe (fail "Unknown task urgency") pure (urgencyFromText rawUrgency)
    rawImportance <- value .: "importance"
    taskImportance <-
      maybe (fail "Unknown task importance") pure (importanceFromText rawImportance)
    TaskInputRequest
      <$> value .: "title"
      <*> value .: "description"
      <*> pure taskStatus
      <*> pure taskUrgency
      <*> pure taskImportance
      <*> (TaskOwner <$> value .: "taskOwner")
      <*> (OutcomeOwner <$> value .: "outcomeOwner")
      <*> value .: "expectedResult"

instance FromJSON SubmissionRequest where
  parseJSON = withObject "SubmissionRequest" $ \value ->
    SubmissionRequest . TaskOwner <$> value .: "taskOwner" <*> value .: "submittedResult"

instance FromJSON ReviewRequest where
  parseJSON = withObject "ReviewRequest" $ \value ->
    ReviewRequest . OutcomeOwner <$> value .: "outcomeOwner" <*> value .:? "reviewComment"

instance FromJSON OutcomeInputRequest where
  parseJSON = withObject "OutcomeInputRequest" $ \value ->
    OutcomeInputRequest
      <$> value .: "outcomeDescription"
      <*> (OutcomeOwner <$> value .: "outcomeOwner")
      <*> value .: "taskIds"

instance FromJSON SignUpRequest where
  parseJSON = withObject "SignUpRequest" $ \value ->
    SignUpRequest <$> value .: "email" <*> value .: "displayName" <*> value .: "password"

instance FromJSON LoginRequest where
  parseJSON = withObject "LoginRequest" $ \value ->
    LoginRequest <$> value .: "email" <*> value .: "password"

instance FromJSON ProfileUpdateRequest where
  parseJSON = withObject "ProfileUpdateRequest" $ \value ->
    ProfileUpdateRequest <$> value .: "displayName"

instance ToJSON TaskResponse where
  toJSON
    ( TaskResponse
        identifier
        taskTitle
        taskDescription
        taskStatus
        taskUrgency
        taskImportance
        taskQuadrant
        (TaskOwner taskOwnerName)
        (OutcomeOwner outcomeOwnerName)
        taskExpectedResult
        taskSubmittedResult
        taskReviewComment
      ) =
      object
        [ "taskId" .= identifier
        , "title" .= taskTitle
        , "description" .= taskDescription
        , "status" .= statusText taskStatus
        , "urgency" .= urgencyText taskUrgency
        , "importance" .= importanceText taskImportance
        , "quadrant" .= quadrantText taskQuadrant
        , "taskOwner" .= taskOwnerName
        , "outcomeOwner" .= outcomeOwnerName
        , "expectedResult" .= taskExpectedResult
        , "submittedResult" .= taskSubmittedResult
        , "reviewComment" .= taskReviewComment
        ]

instance ToJSON OutcomeResponse where
  toJSON
    ( OutcomeResponse
        identifier
        descriptionText
        (OutcomeOwner owner)
        taskIds
        results
        finalStatus
      ) =
      object
        [ "outcomeId" .= identifier
        , "outcomeDescription" .= descriptionText
        , "outcomeOwner" .= owner
        , "taskIds" .= taskIds
        , "results" .= results
        , "status" .= statusText finalStatus
        ]

instance ToJSON ProfileResponse where
  toJSON (ProfileResponse identifier email displayName) =
    object
      [ "id" .= identifier
      , "email" .= email
      , "displayName" .= displayName
      ]

instance ToJSON SessionResponse where
  toJSON (SessionResponse token profile) = object ["token" .= token, "user" .= profile]

application :: TaskRepository IO -> UserRepository IO -> Application
application repository userRepository request respond =
  case pathInfo request of
    ["api", "auth", "signup"] | requestMethod request == methodPost ->
      withSignUp request respond $ \(SignUpRequest email displayName password) -> do
        result <- AuthService.signUp userRepository (SignUpInput email displayName password)
        respondSessionResult status201 respond result
    ["api", "auth", "login"] | requestMethod request == methodPost ->
      withLogin request respond $ \(LoginRequest email password) -> do
        result <- AuthService.login userRepository email password
        respondSessionResult status200 respond result
    ["api", "auth", "logout"] | requestMethod request == methodPost ->
      withBearerToken request respond $ \token -> do
        AuthService.logout userRepository token
        respond (responseLBS status204 [] "")
    ["api", "auth", "me"] | requestMethod request == methodGet ->
      withBearerToken request respond $ \token -> do
        result <- AuthService.currentUser userRepository token
        respondProfileResult respond result
    ["api", "auth", "me"] | requestMethod request == methodPut ->
      withBearerToken request respond $ \token ->
        withProfileUpdate request respond $ \(ProfileUpdateRequest displayName) -> do
          result <- AuthService.updateProfile userRepository token (ProfileUpdate displayName)
          respondProfileResult respond result
    ["api", "task"] | requestMethod request == methodGet -> do
      tasks <- TaskService.listTasks repository
      respond (json status200 (map toResponse tasks))
    ["api", "task"] | requestMethod request == methodPost ->
      withTaskInput request respond $ \input -> do
        result <- TaskService.createTask repository input
        case result of
          Left err -> respond (domainError err)
          Right task -> respond (json status201 (toResponse task))
    ["api", "task", rawId, "submit"] | requestMethod request == methodPost ->
      withId rawId respond $ \identifier ->
        withSubmission request respond $ \(SubmissionRequest owner taskResult) -> do
          result <- TaskService.submitTaskResult repository identifier owner taskResult
          respondTaskResult respond result
    ["api", "task", rawId, "approve"] | requestMethod request == methodPost ->
      withId rawId respond $ \identifier ->
        withReview request respond $ \(ReviewRequest owner comment) -> do
          result <- TaskService.approveTaskResult repository identifier owner comment
          respondTaskResult respond result
    ["api", "task", rawId, "revision"] | requestMethod request == methodPost ->
      withId rawId respond $ \identifier ->
        withReview request respond $ \(ReviewRequest owner comment) -> do
          result <-
            TaskService.requestTaskRevision
              repository
              identifier
              owner
              (fromMaybe "수정이 필요합니다." comment)
          respondTaskResult respond result
    ["api", "task", rawId] | requestMethod request == methodPut ->
      withId rawId respond $ \identifier ->
        withTaskInput request respond $ \input -> do
          result <- TaskService.updateTask repository identifier input
          case result of
            Left err -> respond (domainError err)
            Right Nothing -> respond notFound
            Right (Just task) -> respond (json status200 (toResponse task))
    ["api", "task", rawId] | requestMethod request == methodDelete ->
      withId rawId respond $ \identifier -> do
        wasDeleted <- TaskService.deleteTask repository identifier
        if wasDeleted
          then respond (responseLBS status204 [] "")
          else respond notFound
    ["api", "outcome"] | requestMethod request == methodGet -> do
      outcomes <- TaskService.listOutcomes repository
      respond (json status200 (map outcomeToResponse outcomes))
    ["api", "outcome"] | requestMethod request == methodPost ->
      withOutcomeInput request respond $ \(OutcomeInputRequest descriptionText owner taskIds) -> do
        result <-
          TaskService.createOutcome repository (OutcomeInput descriptionText owner taskIds)
        case result of
          Left err -> respond (domainError err)
          Right outcome -> respond (json status201 (outcomeToResponse outcome))
    _ -> staticFile request respond
  where
    notFound = responseLBS status404 [jsonContentType] "{\"error\":\"업무를 찾을 수 없습니다.\"}"

withId
  :: Text
  -> (Response -> IO ResponseReceived)
  -> (Int -> IO ResponseReceived)
  -> IO ResponseReceived
withId rawId respond action =
  maybe
    (respond (responseLBS status400 [jsonContentType] "{\"error\":\"Invalid task id\"}"))
    action
    (readMaybe (Text.unpack rawId))

withTaskInput
  :: Request
  -> (Response -> IO ResponseReceived)
  -> (TaskInput -> IO ResponseReceived)
  -> IO ResponseReceived
withTaskInput request respond action = do
  body <- strictRequestBody request
  case eitherDecode body of
    Left _ -> respond (responseLBS status400 [jsonContentType] "{\"error\":\"Invalid task input\"}")
    Right
      ( TaskInputRequest
          taskTitle
          taskDescription
          taskStatus
          taskUrgency
          taskImportance
          taskOwnerName
          outcomeOwnerName
          expected
        ) ->
        action
          ( TaskInput
              taskTitle
              taskDescription
              taskStatus
              taskUrgency
              taskImportance
              taskOwnerName
              outcomeOwnerName
              expected
          )

withSubmission
  :: Request
  -> (Response -> IO ResponseReceived)
  -> (SubmissionRequest -> IO ResponseReceived)
  -> IO ResponseReceived
withSubmission request respond action = do
  body <- strictRequestBody request
  case eitherDecode body of
    Left _ ->
      respond
        (responseLBS status400 [jsonContentType] "{\"error\":\"Invalid result submission\"}")
    Right submission -> action submission

withReview
  :: Request
  -> (Response -> IO ResponseReceived)
  -> (ReviewRequest -> IO ResponseReceived)
  -> IO ResponseReceived
withReview request respond action = do
  body <- strictRequestBody request
  case eitherDecode body of
    Left _ ->
      respond (responseLBS status400 [jsonContentType] "{\"error\":\"Invalid result review\"}")
    Right review -> action review

withOutcomeInput
  :: Request
  -> (Response -> IO ResponseReceived)
  -> (OutcomeInputRequest -> IO ResponseReceived)
  -> IO ResponseReceived
withOutcomeInput request respond action = do
  body <- strictRequestBody request
  case eitherDecode body of
    Left _ ->
      respond (responseLBS status400 [jsonContentType] "{\"error\":\"Invalid outcome input\"}")
    Right input -> action input

withSignUp
  :: Request
  -> (Response -> IO ResponseReceived)
  -> (SignUpRequest -> IO ResponseReceived)
  -> IO ResponseReceived
withSignUp request respond action = do
  body <- strictRequestBody request
  case eitherDecode body of
    Left _ ->
      respond (responseLBS status400 [jsonContentType] "{\"error\":\"Invalid sign-up input\"}")
    Right input -> action input

withLogin
  :: Request
  -> (Response -> IO ResponseReceived)
  -> (LoginRequest -> IO ResponseReceived)
  -> IO ResponseReceived
withLogin request respond action = do
  body <- strictRequestBody request
  case eitherDecode body of
    Left _ ->
      respond (responseLBS status400 [jsonContentType] "{\"error\":\"Invalid login input\"}")
    Right input -> action input

withProfileUpdate
  :: Request
  -> (Response -> IO ResponseReceived)
  -> (ProfileUpdateRequest -> IO ResponseReceived)
  -> IO ResponseReceived
withProfileUpdate request respond action = do
  body <- strictRequestBody request
  case eitherDecode body of
    Left _ ->
      respond (responseLBS status400 [jsonContentType] "{\"error\":\"Invalid profile input\"}")
    Right input -> action input

withBearerToken
  :: Request
  -> (Response -> IO ResponseReceived)
  -> (Text -> IO ResponseReceived)
  -> IO ResponseReceived
withBearerToken request respond action =
  case lookup "Authorization" (requestHeaders request) >>= bearerToken of
    Nothing -> respond (authError AuthenticationRequired)
    Just token -> action token

bearerToken :: ByteString -> Maybe Text
bearerToken value = Text.stripPrefix "Bearer " (TextEncoding.decodeUtf8 value)

respondSessionResult
  :: HTTP.Status
  -> (Response -> IO ResponseReceived)
  -> Either AuthError AuthService.Session
  -> IO ResponseReceived
respondSessionResult httpStatus respond result =
  case result of
    Left err -> respond (authError err)
    Right session -> respond (json httpStatus (sessionResponse session))

respondProfileResult
  :: (Response -> IO ResponseReceived)
  -> Either AuthError UserProfile
  -> IO ResponseReceived
respondProfileResult respond result =
  case result of
    Left err -> respond (authError err)
    Right profile -> respond (json status200 (profileResponse profile))

sessionResponse :: AuthService.Session -> SessionResponse
sessionResponse session =
  SessionResponse
    (AuthService.sessionToken session)
    (profileResponse (AuthService.sessionUser session))

profileResponse :: UserProfile -> ProfileResponse
profileResponse profile =
  ProfileResponse
    (profileId profile)
    (profileEmail profile)
    (profileDisplayName profile)

authError :: AuthError -> Response
authError InvalidEmail = responseLBS status400 [jsonContentType] "{\"error\":\"유효한 이메일을 입력해 주세요.\"}"
authError EmptyDisplayName = responseLBS status400 [jsonContentType] "{\"error\":\"표시 이름을 입력해 주세요.\"}"
authError PasswordTooShort = responseLBS status400 [jsonContentType] "{\"error\":\"비밀번호는 8자 이상이어야 합니다.\"}"
authError DuplicateEmail = responseLBS status409 [jsonContentType] "{\"error\":\"이미 가입된 이메일입니다.\"}"
authError InvalidCredentials = responseLBS status401 [jsonContentType] "{\"error\":\"이메일 또는 비밀번호가 올바르지 않습니다.\"}"
authError AuthenticationRequired = responseLBS status401 [jsonContentType] "{\"error\":\"로그인이 필요합니다.\"}"

domainError :: TaskError -> Response
domainError EmptyTitle = responseLBS status400 [jsonContentType] "{\"error\":\"Task title is required\"}"
domainError EmptyExpectedResult = responseLBS status400 [jsonContentType] "{\"error\":\"Expected result is required\"}"
domainError EmptySubmittedResult = responseLBS status400 [jsonContentType] "{\"error\":\"Submitted result is required\"}"
domainError EmptyOutcomeDescription =
  responseLBS status400 [jsonContentType] "{\"error\":\"Outcome description is required\"}"
domainError NoTasksSelected =
  responseLBS
    status400
    [jsonContentType]
    "{\"error\":\"Select at least one approved task\"}"
domainError NotTaskOwner =
  responseLBS
    status400
    [jsonContentType]
    "{\"error\":\"Only the Task Owner can submit a result\"}"
domainError NotOutcomeOwner =
  responseLBS
    status400
    [jsonContentType]
    "{\"error\":\"Only the Outcome Owner can review these tasks\"}"
domainError ResultNotSubmitted = responseLBS status400 [jsonContentType] "{\"error\":\"Submit a result before review\"}"
domainError TaskNotReadyForReview = responseLBS status400 [jsonContentType] "{\"error\":\"Task is not ready for review\"}"
domainError TaskNotApproved =
  responseLBS
    status400
    [jsonContentType]
    "{\"error\":\"All selected tasks must be approved\"}"

toResponse :: TaskItem -> TaskResponse
toResponse task =
  TaskResponse
    (taskId task)
    (title task)
    (description task)
    (status task)
    (urgency task)
    (importance task)
    (quadrantOf task)
    (taskOwner task)
    (reviewOwner task)
    (expectedResult task)
    (submittedResult task)
    (reviewComment task)

outcomeToResponse :: Outcome -> OutcomeResponse
outcomeToResponse outcome =
  OutcomeResponse
    (outcomeId outcome)
    (outcomeDescription outcome)
    (outcomeOwner outcome)
    (sourceTaskIds outcome)
    (outcomeResults outcome)
    (outcomeStatus outcome)

respondTaskResult
  :: (Response -> IO ResponseReceived)
  -> Either TaskError (Maybe TaskItem)
  -> IO ResponseReceived
respondTaskResult respond result =
  case result of
    Left err -> respond (domainError err)
    Right Nothing -> respond (responseLBS status404 [jsonContentType] "{\"error\":\"업무를 찾을 수 없습니다.\"}")
    Right (Just task) -> respond (json status200 (toResponse task))

json :: (ToJSON value) => HTTP.Status -> value -> Response
json httpStatus value = responseLBS httpStatus [jsonContentType] (encode value)

jsonContentType :: HTTP.Header
jsonContentType = ("Content-Type", "application/json; charset=utf-8")

statusText :: Status -> Text
statusText taskStatus =
  case taskStatus of
    Draft -> "Draft"
    Reviewed -> "Reviewed"
    Submitted -> "Submitted"
    Approved -> "Approved"
    Effective -> "Effective"

statusFromText :: Text -> Maybe Status
statusFromText rawStatus =
  case rawStatus of
    "Draft" -> Just Draft
    "Reviewed" -> Just Reviewed
    "Submitted" -> Just Submitted
    "Approved" -> Just Approved
    "Effective" -> Just Effective
    _ -> Nothing

urgencyText :: Urgency -> Text
urgencyText taskUrgency =
  case taskUrgency of
    Urgent -> "Urgent"
    NotUrgent -> "NotUrgent"

urgencyFromText :: Text -> Maybe Urgency
urgencyFromText rawUrgency =
  case rawUrgency of
    "Urgent" -> Just Urgent
    "NotUrgent" -> Just NotUrgent
    _ -> Nothing

importanceText :: Importance -> Text
importanceText taskImportance =
  case taskImportance of
    Important -> "Important"
    NotImportant -> "NotImportant"

importanceFromText :: Text -> Maybe Importance
importanceFromText rawImportance =
  case rawImportance of
    "Important" -> Just Important
    "NotImportant" -> Just NotImportant
    _ -> Nothing

quadrantText :: Quadrant -> Text
quadrantText taskQuadrant =
  case taskQuadrant of
    DoFirst -> "DoFirst"
    Schedule -> "Schedule"
    Delegate -> "Delegate"
    Eliminate -> "Eliminate"

staticFile :: Request -> (Response -> IO ResponseReceived) -> IO ResponseReceived
staticFile request respond =
  case pathInfo request of
    [] ->
      respond
        ( responseFile
            status200
            [("Content-Type", "text/html; charset=utf-8")]
            "web/index.html"
            Nothing
        )
    ["elm.js"] ->
      respond
        ( responseFile
            status200
            [("Content-Type", "application/javascript; charset=utf-8")]
            "web/elm.js"
            Nothing
        )
    ["styles.css"] ->
      respond
        ( responseFile
            status200
            [("Content-Type", "text/css; charset=utf-8")]
            "web/styles.css"
            Nothing
        )
    _ ->
      respond
        (responseLBS status404 [("Content-Type", "text/plain; charset=utf-8")] "Not found")
