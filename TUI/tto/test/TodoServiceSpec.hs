{-# LANGUAGE OverloadedStrings #-}

module TodoServiceSpec
    ( spec
    ) where

import qualified App
import qualified Config
import qualified DB
import           TodoService

import           Database.SQLite.Simple (open)

import           Flow       ((<|))
import qualified I18n
import           Test.Hspec

-- | 테스트용 TodoRow 헬퍼
mkTodoRow :: DB.TodoId -> String -> String -> DB.TodoRow
mkTodoRow tid action status =
    DB.TodoRow
        { DB.todoId = tid
        , DB.todoAction = action
        , DB.todoStatus = status
        , DB.todoCreatedAt = "2025-01-01 00:00"
        , DB.todoSubject = Nothing
        , DB.todoIndirectObject = Nothing
        , DB.todoDirectObject = Nothing
        , DB.todoStatusChangedAt = Nothing
        }

-- | 테스트용 AppEnv 생성 헬퍼
mkTestEnv :: IO App.AppEnv
mkTestEnv = do
    conn <- open ":memory:"
    DB.initDB conn
    pure $ App.AppEnv conn I18n.defaultMessages Config.defaultKeyBindings

spec :: Spec
spec = do
  describe "findTodoById" <| do
    let rows =
            [ mkTodoRow 1 "할 일 1" "registered"
            , mkTodoRow 2 "할 일 2" "in_progress"
            , mkTodoRow 3 "할 일 3" "completed"
            ]

    it "존재하는 ID로 Todo를 찾아야 함" <| do
      case findTodoById 1 rows of
        Just row -> DB.todoAction row `shouldBe` "할 일 1"
        Nothing  -> expectationFailure "Todo를 찾지 못함"

    it "중간 ID로 Todo를 찾아야 함" <| do
      case findTodoById 2 rows of
        Just row -> DB.todoAction row `shouldBe` "할 일 2"
        Nothing  -> expectationFailure "Todo를 찾지 못함"

    it "마지막 ID로 Todo를 찾아야 함" <| do
      case findTodoById 3 rows of
        Just row -> DB.todoStatus row `shouldBe` "completed"
        Nothing  -> expectationFailure "Todo를 찾지 못함"

    it "존재하지 않는 ID는 Nothing을 반환해야 함" <| do
      findTodoById 999 rows `shouldBe` Nothing

    it "빈 리스트에서 Nothing을 반환해야 함" <| do
      findTodoById 1 [] `shouldBe` Nothing

    it "음수 ID도 처리해야 함" <| do
      findTodoById (-1) rows `shouldBe` Nothing

  describe "strip" <| do
    it "앞뒤 공백을 제거해야 함" <| do
      strip "  hello  " `shouldBe` "hello"

    it "내부 연속 공백을 하나로 축소해야 함" <| do
      strip "hello   world" `shouldBe` "hello world"

    it "빈 문자열은 빈 문자열을 반환해야 함" <| do
      strip "" `shouldBe` ""

    it "공백만 있는 문자열은 빈 문자열을 반환해야 함" <| do
      strip "   " `shouldBe` ""

    it "한글 문자열의 공백도 정리해야 함" <| do
      strip "  안녕  하세요  " `shouldBe` "안녕 하세요"

  describe "normalizeField" <| do
    it "Nothing은 Nothing을 반환해야 함" <| do
      normalizeField Nothing `shouldBe` Nothing

    it "빈 문자열은 Nothing으로 변환해야 함" <| do
      normalizeField (Just "") `shouldBe` Nothing

    it "공백만 있는 문자열은 Nothing으로 변환해야 함" <| do
      normalizeField (Just "   ") `shouldBe` Nothing

    it "정상 문자열은 trim된 Just를 반환해야 함" <| do
      normalizeField (Just "  hello  ") `shouldBe` Just "hello"

    it "한글 문자열도 정규화해야 함" <| do
      normalizeField (Just "  할 일  ") `shouldBe` Just "할 일"

  describe "createNewTodo (입력 검증)" <| do
    it "빈 action은 Nothing을 반환해야 함" <| do
      env <- mkTestEnv
      result <- App.runAppM env <| createNewTodo "" Nothing Nothing Nothing
      result `shouldBe` Nothing

    it "공백만 있는 action은 Nothing을 반환해야 함" <| do
      env <- mkTestEnv
      result <- App.runAppM env <| createNewTodo "   " Nothing Nothing Nothing
      result `shouldBe` Nothing

    it "유효한 action은 Just TodoId를 반환해야 함" <| do
      env <- mkTestEnv
      result <- App.runAppM env <| createNewTodo "할 일" Nothing Nothing Nothing
      result `shouldSatisfy` (/= Nothing)

    it "앞뒤 공백이 있는 action도 정규화하여 생성해야 함" <| do
      env <- mkTestEnv
      maybeTid <- App.runAppM env <| createNewTodo "  할 일  " Nothing Nothing Nothing
      maybeTid `shouldSatisfy` (/= Nothing)
      let Just tid = maybeTid
      todos <- App.runAppM env loadAllTodos
      case findTodoById tid todos of
        Just row -> DB.todoAction row `shouldBe` "할 일"
        Nothing  -> expectationFailure "생성된 Todo를 찾지 못함"

  describe "cycleStatusForward (통합 테스트)" <| do
    it "전체 상태 순환: Registered → InProgress → Cancelled → Completed → Registered" <| do
      env <- mkTestEnv
      maybeTid <- App.runAppM env <| createNewTodo "순환 테스트" Nothing Nothing Nothing
      let Just tid = maybeTid

      -- registered -> in_progress
      App.runAppM env <| cycleStatusForward tid "registered"
      todos1 <- App.runAppM env loadAllTodos
      case findTodoById tid todos1 of
        Just row -> DB.todoStatus row `shouldBe` "in_progress"
        Nothing  -> expectationFailure "Todo를 찾지 못함"

      -- in_progress -> cancelled
      App.runAppM env <| cycleStatusForward tid "in_progress"
      todos2 <- App.runAppM env loadAllTodos
      case findTodoById tid todos2 of
        Just row -> DB.todoStatus row `shouldBe` "cancelled"
        Nothing  -> expectationFailure "Todo를 찾지 못함"

      -- cancelled -> completed
      App.runAppM env <| cycleStatusForward tid "cancelled"
      todos3 <- App.runAppM env loadAllTodos
      case findTodoById tid todos3 of
        Just row -> DB.todoStatus row `shouldBe` "completed"
        Nothing  -> expectationFailure "Todo를 찾지 못함"

      -- completed -> registered
      App.runAppM env <| cycleStatusForward tid "completed"
      todos4 <- App.runAppM env loadAllTodos
      case findTodoById tid todos4 of
        Just row -> DB.todoStatus row `shouldBe` "registered"
        Nothing  -> expectationFailure "Todo를 찾지 못함"

    it "알 수 없는 상태에서는 변경하지 않아야 함" <| do
      env <- mkTestEnv
      maybeTid <- App.runAppM env <| createNewTodo "테스트" Nothing Nothing Nothing
      let Just tid = maybeTid
      -- 알 수 없는 상태로 시도
      App.runAppM env <| cycleStatusForward tid "unknown_status"
      todos <- App.runAppM env loadAllTodos
      case findTodoById tid todos of
        Just row -> DB.todoStatus row `shouldBe` "registered"
        Nothing  -> expectationFailure "Todo를 찾지 못함"
