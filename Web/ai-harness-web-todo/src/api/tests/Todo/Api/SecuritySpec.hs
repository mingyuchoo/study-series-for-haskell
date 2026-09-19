{-# LANGUAGE OverloadedStrings #-}

-- | 입력 검증과 오류 노출 범위 검증입니다.
--
-- 이 API는 로컬 사용을 전제로 인증이 없습니다. 그 대신 신뢰할 수 없는 입력이
-- 저장 계층까지 도달하지 않는다는 점을 여기서 고정합니다. 인증 경계를 도입한다면
-- 그 자체가 Level 3 변경이며 ADR이 필요합니다(@docs/ai/RISK_LEVELS.md@).
module Todo.Api.SecuritySpec (spec) where

import Data.Aeson (Value (..), object, (.=))
import qualified Data.Aeson as Aeson
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.Text as T
import Test.Hspec (Spec, describe, it, shouldBe, shouldSatisfy)
import Todo.Api.Harness (get, jsonBody, post, put, statusOf, withApi)

spec :: Spec
spec = describe "api 입력 검증" $ do
  it "제목이 없는 요청을 400으로 거부한다" $ do
    response <- withApi (post "/todos" (Aeson.encode (object ["list" .= ("inbox" :: String)])))
    statusOf response `shouldBe` 400

  it "공백만 있는 제목을 거부한다" $ do
    response <- withApi (post "/todos" (Aeson.encode (object ["title" .= ("   " :: String)])))
    statusOf response `shouldBe` 400
    fmap (fieldOf "code") (jsonBody response) `shouldBe` Just (Just (String "invalid_request"))

  it "지나치게 긴 제목을 거부한다" $ do
    let longTitle = T.replicate 500 "가"
    response <- withApi (post "/todos" (Aeson.encode (object ["title" .= longTitle])))
    statusOf response `shouldBe` 400

  it "허용되지 않은 문자가 든 태그를 거부한다" $ do
    let body = object ["title" .= ("제목" :: String), "tags" .= (["../../etc/passwd"] :: [String])]
    response <- withApi (post "/todos" (Aeson.encode body))
    statusOf response `shouldBe` 400

  it "알 수 없는 우선순위를 거부한다" $ do
    let body = object ["title" .= ("제목" :: String), "priority" .= ("critical" :: String)]
    response <- withApi (post "/todos" (Aeson.encode body))
    statusOf response `shouldBe` 400

  it "알 수 없는 상태 값을 거부한다" $ do
    response <- withApi $ do
      _ <- post "/todos" (Aeson.encode (object ["title" .= ("제목" :: String)]))
      put "/todos/1/status" (Aeson.encode (object ["status" .= ("deleted" :: String)]))
    statusOf response `shouldBe` 400

  it "잘못된 JSON 본문을 400으로 거부한다" $ do
    response <- withApi (post "/todos" "{ not json")
    statusOf response `shouldBe` 400

  it "식별자가 숫자가 아니면 400으로 거부한다" $ do
    response <- withApi (get "/todos/abc")
    statusOf response `shouldBe` 400

  it "제목에 든 SQL 조각을 값으로만 다룬다" $ do
    let injection = "'; DROP TABLE todos; --" :: T.Text
    response <- withApi $ do
      _ <- post "/todos" (Aeson.encode (object ["title" .= injection]))
      get "/todos"
    statusOf response `shouldBe` 200
    fmap lengthOf (jsonBody response) `shouldBe` Just 1

  it "오류 메시지가 저장 경로나 SQL을 노출하지 않는다" $ do
    response <- withApi (get "/todos/999")
    let message = jsonBody response >>= fieldOf "message"
    message `shouldSatisfy` \value -> case value of
      Just (String text) ->
        not (T.isInfixOf "SELECT" text)
          && not (T.isInfixOf "todo.db" text)
          && not (T.isInfixOf "/" text)
      _ -> False

fieldOf :: Aeson.Key -> Value -> Maybe Value
fieldOf key (Object o) = KeyMap.lookup key o
fieldOf _ _ = Nothing

lengthOf :: Value -> Int
lengthOf (Array xs) = length xs
lengthOf _ = -1
