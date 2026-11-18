{-# LANGUAGE OverloadedStrings #-}

module Todo.Interface.HTTP.TodoApiSpec (spec) where

import Control.Monad.IO.Class (liftIO)
import Data.Aeson (Value (..), eitherDecode)
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Text (Text)
import Network.HTTP.Types (
    hContentType,
    methodDelete,
    methodGet,
    methodPost,
    status200,
    status201,
    status204,
    status400,
    status404,
 )
import Network.Wai (Application)
import Network.Wai.Test (simpleBody, simpleStatus)
import Support.Fixtures (fixedTime, fixedTodoId, newInMemoryRepository)
import Test.Hspec (Spec, describe, it, shouldBe, shouldSatisfy)
import Test.Hspec.Wai (request, with)
import Todo.Interface.HTTP.Handler (HandlerEnv (..))
import Todo.Interface.HTTP.Server (mkApplication)

spec :: Spec
spec = with testApplication $ do
    describe "POST /api/v1/todos" $ do
        it "returns 201 for a valid Todo" $ do
            response <- request methodPost "/api/v1/todos" [(hContentType, "application/json")] "{\"title\":\"Buy milk\"}"
            liftIO $ simpleStatus response `shouldBe` status201

        it "returns 400 for a whitespace-only title" $ do
            response <- request methodPost "/api/v1/todos" [(hContentType, "application/json")] "{\"title\":\"   \"}"
            liftIO $ simpleStatus response `shouldBe` status400

    describe "POST /api/v1/todos/:todoId/complete" $ do
        it "returns a completed Todo with a completion timestamp" $ do
            _ <- request methodPost "/api/v1/todos" [(hContentType, "application/json")] "{\"title\":\"Buy milk\"}"
            response <- request methodPost "/api/v1/todos/550e8400-e29b-41d4-a716-446655440000/complete" [] ""
            liftIO $ do
                simpleStatus response `shouldBe` status200
                status <- responseField (simpleBody response) "status"
                completedAt <- responseField (simpleBody response) "completedAt"
                status `shouldBe` String "completed"
                completedAt `shouldSatisfy` isJsonString

        it "is idempotent and preserves the original completion timestamp" $ do
            _ <- request methodPost "/api/v1/todos" [(hContentType, "application/json")] "{\"title\":\"Buy milk\"}"
            first <- request methodPost "/api/v1/todos/550e8400-e29b-41d4-a716-446655440000/complete" [] ""
            second <- request methodPost "/api/v1/todos/550e8400-e29b-41d4-a716-446655440000/complete" [] ""
            liftIO $ do
                simpleStatus first `shouldBe` status200
                simpleStatus second `shouldBe` status200
                firstCompletedAt <- responseField (simpleBody first) "completedAt"
                secondCompletedAt <- responseField (simpleBody second) "completedAt"
                secondCompletedAt `shouldBe` firstCompletedAt

        it "returns 404 for a missing valid Todo ID" $ do
            response <- request methodPost "/api/v1/todos/550e8400-e29b-41d4-a716-446655440000/complete" [] ""
            liftIO $ simpleStatus response `shouldBe` status404

    describe "DELETE /api/v1/todos/:todoId" $ do
        it "returns 204 and makes the Todo unavailable" $ do
            _ <- request methodPost "/api/v1/todos" [(hContentType, "application/json")] "{\"title\":\"Buy milk\"}"
            deleted <- request methodDelete "/api/v1/todos/550e8400-e29b-41d4-a716-446655440000" [] ""
            fetched <- request methodGet "/api/v1/todos/550e8400-e29b-41d4-a716-446655440000" [] ""
            liftIO $ do
                simpleStatus deleted `shouldBe` status204
                simpleStatus fetched `shouldBe` status404

        it "returns 404 for a missing valid Todo ID" $ do
            response <- request methodDelete "/api/v1/todos/550e8400-e29b-41d4-a716-446655440000" [] ""
            liftIO $ simpleStatus response `shouldBe` status404

testApplication :: IO Application
testApplication = do
    repo <- newInMemoryRepository
    pure $
        mkApplication
            HandlerEnv
                { handlerRepository = repo
                , handlerGenerateTodoId = pure fixedTodoId
                , handlerCurrentTime = pure fixedTime
                }

responseField :: LazyByteString.ByteString -> Text -> IO Value
responseField body field =
    case eitherDecode body of
        Left err -> fail ("invalid JSON response: " <> err)
        Right (Object object) ->
            case KeyMap.lookup (Key.fromText field) object of
                Nothing -> fail ("response field not found: " <> show field)
                Just value -> pure value
        Right _ -> fail "expected a JSON object response"

isJsonString :: Value -> Bool
isJsonString (String _) = True
isJsonString _ = False
