{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import qualified Application.AuthService as AuthService
import qualified Application.TaskService as TaskService
import Control.Exception (bracket)
import Control.Monad (forM_, when)
import Data.List (find)
import Domain.Task
import Domain.User
  ( AuthError (..)
  , ProfileUpdate (..)
  , SignUpInput (..)
  , profileDisplayName
  )
import Infrastructure.InMemoryTaskRepository (newInMemoryTaskRepository)
import Infrastructure.InMemoryUserRepository (newInMemoryUserRepository)
import Infrastructure.SQLiteDatabase
  ( closeSQLiteDatabase
  , openSQLiteDatabase
  )
import Infrastructure.SQLiteTaskRepository
  ( newSQLiteTaskRepository
  , seedInitialTasks
  )
import Infrastructure.SQLiteUserRepository (newSQLiteUserRepository)
import System.Directory (doesFileExist, getTemporaryDirectory, removeFile)
import System.Exit (exitFailure)
import System.IO (hClose, openTempFile)

main :: IO ()
main = do
  let input =
        TaskInput
          "업무"
          "설명"
          Submitted
          Urgent
          Important
          (TaskOwner "담당자")
          (OutcomeOwner "성과 담당자")
          "완료된 보고서"
      created = createTask 7 input
      updated =
        updateTask
          created
          ( TaskInput
              "수정 업무"
              "수정 설명"
              Approved
              NotUrgent
              NotImportant
              (TaskOwner "담당자")
              (OutcomeOwner "성과 담당자")
              "수정된 보고서"
          )
  assert "생성 시 ID와 상태를 보존한다" (taskId created == 7 && status created == Submitted)
  assert "수정 시 내용과 상태를 갱신한다" (title updated == "수정 업무" && status updated == Approved)
  assert
    "수정 시 우선순위를 갱신한다"
    (urgency updated == NotUrgent && importance updated == NotImportant)
  assert
    "긴급도와 중요도를 사분면으로 변환한다"
    ( quadrantOf created == DoFirst
        && toQuadrant NotUrgent Important == Schedule
        && toQuadrant Urgent NotImportant == Delegate
        && toQuadrant NotUrgent NotImportant == Eliminate
    )
  assert
    "빈 제목을 거부한다"
    ( validateTaskInput
        ( TaskInput
            "  "
            "설명"
            Draft
            NotUrgent
            Important
            (TaskOwner "담당자")
            (OutcomeOwner "성과 담당자")
            "결과"
        )
        == Left EmptyTitle
    )
  repository <- newInMemoryTaskRepository []
  createdInRepository <- TaskService.createTask repository input
  assert
    "유스케이스가 유효한 업무를 생성한다"
    ( createdInRepository
        == Right
          ( TaskItem
              1
              "업무"
              "설명"
              Submitted
              Urgent
              Important
              (TaskOwner "담당자")
              (OutcomeOwner "성과 담당자")
              "완료된 보고서"
              Nothing
              Nothing
          )
    )
  deleted <- TaskService.deleteTask repository 1
  assert "유스케이스가 존재하는 업무를 삭제한다" deleted
  userRepository <- newInMemoryUserRepository
  signedUp <-
    AuthService.signUp
      userRepository
      (SignUpInput "member@example.com" "새 사용자" "safe-password")
  session <- expectRight "유효한 사용자를 가입시킨다" signedUp
  duplicate <-
    AuthService.signUp
      userRepository
      (SignUpInput "member@example.com" "다른 사용자" "safe-password")
  assert "중복 이메일 가입을 거부한다" (duplicate == Left DuplicateEmail)
  invalidLogin <- AuthService.login userRepository "member@example.com" "wrong-password"
  assert "잘못된 비밀번호 로그인을 거부한다" (invalidLogin == Left InvalidCredentials)
  loggedIn <- AuthService.login userRepository "member@example.com" "safe-password"
  loginSession <- expectRight "올바른 비밀번호로 로그인한다" loggedIn
  updatedProfile <-
    AuthService.updateProfile
      userRepository
      (AuthService.sessionToken loginSession)
      (ProfileUpdate "변경된 사용자")
  profile <- expectRight "로그인한 사용자가 프로필을 수정한다" updatedProfile
  assert "표시 이름을 갱신한다" (profileDisplayName profile == "변경된 사용자")
  AuthService.logout userRepository (AuthService.sessionToken session)
  loggedOut <- AuthService.currentUser userRepository (AuthService.sessionToken session)
  assert "로그아웃한 세션을 거부한다" (loggedOut == Left AuthenticationRequired)
  testSQLitePersistence
  putStrLn "All domain tests passed"

testSQLitePersistence :: IO ()
testSQLitePersistence = withTemporaryDatabasePath $ \databasePath -> do
  let sqliteInput =
        TaskInput
          "영속 업무"
          "서버 재시작 뒤에도 남아야 합니다."
          Draft
          NotUrgent
          Important
          (TaskOwner "영속 담당자")
          (OutcomeOwner "영속 성과 담당자")
          "영속 결과물"
      seedTask = createTask 1 (sqliteInput {inputTitle = "최초 1회 예시 업무"})
  (approvedTask, createdOutcome, sessionToken, expectedProfile) <-
    bracket
      (openSQLiteDatabase databasePath)
      closeSQLiteDatabase
      ( \database -> do
          repository <- newSQLiteTaskRepository database
          userRepository <- newSQLiteUserRepository database
          seedInitialTasks database [seedTask]
          seedInitialTasks database [seedTask]
          initiallySeeded <- TaskService.listTasks repository
          assert "SQLite 예시 업무를 최초 한 번만 시드한다" (initiallySeeded == [seedTask])
          createdResult <- TaskService.createTask repository sqliteInput
          createdTask <- expectRight "SQLite에 Task를 생성한다" createdResult
          submissionResult <-
            TaskService.submitTaskResult
              repository
              (taskId createdTask)
              (TaskOwner "영속 담당자")
              "완료된 영속 결과물"
          submittedTask <- expectRightMaybe "SQLite Task 결과물을 제출한다" submissionResult
          approvedResult <-
            TaskService.approveTaskResult
              repository
              (taskId submittedTask)
              (OutcomeOwner "영속 성과 담당자")
              (Just "영속 승인")
          approved <- expectRightMaybe "SQLite Task 결과물을 승인한다" approvedResult
          outcomeResult <-
            TaskService.createOutcome
              repository
              ( OutcomeInput
                  "영속 Outcome"
                  (OutcomeOwner "영속 성과 담당자")
                  [taskId approved]
              )
          outcome <- expectRight "SQLite에 Outcome을 생성한다" outcomeResult
          signedUp <-
            AuthService.signUp
              userRepository
              (SignUpInput "persistent@example.com" "영속 사용자" "safe-password")
          sqliteSession <- expectRight "SQLite에 사용자와 세션을 생성한다" signedUp
          updated <-
            AuthService.updateProfile
              userRepository
              (AuthService.sessionToken sqliteSession)
              (ProfileUpdate "재개방 사용자")
          profile <- expectRight "SQLite 사용자 프로필을 갱신한다" updated
          pure (approved, outcome, AuthService.sessionToken sqliteSession, profile)
      )
  bracket
    (openSQLiteDatabase databasePath)
    closeSQLiteDatabase
    ( \database -> do
        repository <- newSQLiteTaskRepository database
        userRepository <- newSQLiteUserRepository database
        seedInitialTasks database [seedTask]
        reopenedTasks <- TaskService.listTasks repository
        assert
          "DB 재개방 뒤 Task와 시드 마커를 보존한다"
          ( length reopenedTasks == 2
              && find ((== taskId approvedTask) . taskId) reopenedTasks == Just approvedTask
          )
        reopenedOutcomes <- TaskService.listOutcomes repository
        assert "DB 재개방 뒤 Outcome을 보존한다" (reopenedOutcomes == [createdOutcome])
        reopenedUser <- AuthService.currentUser userRepository sessionToken
        assert "DB 재개방 뒤 사용자와 유효 세션을 보존한다" (reopenedUser == Right expectedProfile)
    )

withTemporaryDatabasePath :: (FilePath -> IO a) -> IO a
withTemporaryDatabasePath action = do
  temporaryDirectory <- getTemporaryDirectory
  bracket
    ( do
        (databasePath, handle) <- openTempFile temporaryDirectory "general-service-test.sqlite3"
        hClose handle
        pure databasePath
    )
    cleanupDatabaseFiles
    action

cleanupDatabaseFiles :: FilePath -> IO ()
cleanupDatabaseFiles databasePath =
  forM_ [databasePath, databasePath <> "-wal", databasePath <> "-shm"] $ \path -> do
    exists <- doesFileExist path
    when exists (removeFile path)

assert :: String -> Bool -> IO ()
assert label condition =
  if condition
    then putStrLn ("PASS: " <> label)
    else putStrLn ("FAIL: " <> label) >> exitFailure

expectRight :: String -> Either a b -> IO b
expectRight label result =
  case result of
    Right value -> putStrLn ("PASS: " <> label) >> pure value
    Left _ -> putStrLn ("FAIL: " <> label) >> exitFailure

expectRightMaybe :: String -> Either a (Maybe b) -> IO b
expectRightMaybe label result =
  case result of
    Right (Just value) -> putStrLn ("PASS: " <> label) >> pure value
    _ -> putStrLn ("FAIL: " <> label) >> exitFailure
