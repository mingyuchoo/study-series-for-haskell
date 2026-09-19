{-# LANGUAGE OverloadedStrings #-}

-- | @docs/contracts/api/TODO-API-v1.md@에 게시한 계약을 검증합니다.
--
-- 여기서 실패하는 변경은 소비자를 깨뜨리는 변경입니다. 통과시키려면 코드가 아니라
-- 계약 문서와 버전 정책을 먼저 바꿔야 합니다.
module Todo.Api.ContractSpec (spec) where

import Data.Aeson (Value (..), object, (.=))
import qualified Data.Aeson as Aeson
import qualified Data.Aeson.KeyMap as KeyMap
import Data.List (sort)
import Test.Hspec (Spec, describe, it, shouldBe)
import Todo.Api.Harness (delete, get, jsonBody, patch, post, put, statusOf, withApi)

createBody :: Aeson.Value
createBody = object ["title" .= ("보고서 작성" :: String)]

spec :: Spec
spec = describe "TODO-API-v1 계약" $ do
  it "빈 저장소의 목록 조회는 200과 빈 배열이다" $ do
    response <- withApi (get "/todos")
    (statusOf response, jsonBody response) `shouldBe` (200, Just (Aeson.toJSON ([] :: [Int])))

  it "생성은 201과 만들어진 표현을 반환한다" $ do
    response <- withApi (post "/todos" (Aeson.encode createBody))
    statusOf response `shouldBe` 201
    fmap (fieldOf "status") (jsonBody response) `shouldBe` Just (Just (String "pending"))

  it "생성 응답은 계약이 정한 필드를 모두 포함한다" $ do
    response <- withApi (post "/todos" (Aeson.encode createBody))
    let expected =
          [ "id"
          , "title"
          , "list"
          , "status"
          , "priority"
          , "tags"
          , "dueOn"
          , "createdAt"
          , "updatedAt"
          ]
    fmap (sort . keysOf) (jsonBody response) `shouldBe` Just (sort expected)

  it "목록을 지정하지 않으면 inbox에 들어간다" $ do
    response <- withApi (post "/todos" (Aeson.encode createBody))
    fmap (fieldOf "list") (jsonBody response) `shouldBe` Just (Just (String "inbox"))

  it "태그는 정규화되어 저장된다" $ do
    let body = object ["title" .= ("제목" :: String), "tags" .= (["Work", "work"] :: [String])]
    response <- withApi (post "/todos" (Aeson.encode body))
    fmap (fieldOf "tags") (jsonBody response)
      `shouldBe` Just (Just (Aeson.toJSON (["work"] :: [String])))

  it "생성한 할 일을 식별자로 조회할 수 있다" $ do
    response <- withApi $ do
      _ <- post "/todos" (Aeson.encode createBody)
      get "/todos/1"
    (statusOf response, fmap (fieldOf "title") (jsonBody response))
      `shouldBe` (200, Just (Just (String "보고서 작성")))

  it "없는 할 일 조회는 404와 not_found 코드를 반환한다" $ do
    response <- withApi (get "/todos/999")
    statusOf response `shouldBe` 404
    fmap (fieldOf "code") (jsonBody response) `shouldBe` Just (Just (String "not_found"))

  it "상태 변경은 200과 새 상태를 반환한다" $ do
    response <- withApi $ do
      _ <- post "/todos" (Aeson.encode createBody)
      put "/todos/1/status" (Aeson.encode (object ["status" .= ("done" :: String)]))
    (statusOf response, fmap (fieldOf "status") (jsonBody response))
      `shouldBe` (200, Just (Just (String "done")))

  it "같은 상태 변경을 두 번 보내도 200을 반환한다" $ do
    response <- withApi $ do
      _ <- post "/todos" (Aeson.encode createBody)
      let body = Aeson.encode (object ["status" .= ("done" :: String)])
      _ <- put "/todos/1/status" body
      put "/todos/1/status" body
    statusOf response `shouldBe` 200

  it "허용되지 않은 상태 전이는 409와 invalid_transition을 반환한다" $ do
    response <- withApi $ do
      _ <- post "/todos" (Aeson.encode createBody)
      _ <- put "/todos/1/status" (Aeson.encode (object ["status" .= ("archived" :: String)]))
      put "/todos/1/status" (Aeson.encode (object ["status" .= ("in_progress" :: String)]))
    statusOf response `shouldBe` 409
    fmap (fieldOf "code") (jsonBody response)
      `shouldBe` Just (Just (String "invalid_transition"))

  it "부분 수정은 지정하지 않은 필드를 보존한다" $ do
    response <- withApi $ do
      _ <-
        post
          "/todos"
          (Aeson.encode (object ["title" .= ("원래 제목" :: String), "priority" .= ("high" :: String)]))
      patch "/todos/1" (Aeson.encode (object ["title" .= ("새 제목" :: String)]))
    fmap (\v -> (fieldOf "title" v, fieldOf "priority" v)) (jsonBody response)
      `shouldBe` Just (Just (String "새 제목"), Just (String "high"))

  it "dueOn을 null로 보내면 마감일을 제거한다" $ do
    response <- withApi $ do
      _ <-
        post
          "/todos"
          (Aeson.encode (object ["title" .= ("제목" :: String), "dueOn" .= ("2099-09-01" :: String)]))
      patch "/todos/1" (Aeson.encode (object ["dueOn" .= Null]))
    fmap (fieldOf "dueOn") (jsonBody response) `shouldBe` Just (Just Null)

  it "dueOn 필드를 생략하면 마감일을 바꾸지 않는다" $ do
    response <- withApi $ do
      _ <-
        post
          "/todos"
          (Aeson.encode (object ["title" .= ("제목" :: String), "dueOn" .= ("2099-09-01" :: String)]))
      patch "/todos/1" (Aeson.encode (object ["title" .= ("새 제목" :: String)]))
    fmap (fieldOf "dueOn") (jsonBody response) `shouldBe` Just (Just (String "2099-09-01"))

  it "삭제는 204를 반환하고 본문을 비운다" $ do
    response <- withApi $ do
      _ <- post "/todos" (Aeson.encode createBody)
      delete "/todos/1"
    statusOf response `shouldBe` 204

  it "이미 삭제한 할 일의 재삭제는 404이다" $ do
    response <- withApi $ do
      _ <- post "/todos" (Aeson.encode createBody)
      _ <- delete "/todos/1"
      delete "/todos/1"
    statusOf response `shouldBe` 404

  it "status 질의 매개변수로 걸러낼 수 있다" $ do
    response <- withApi $ do
      _ <- post "/todos" (Aeson.encode createBody)
      _ <- post "/todos" (Aeson.encode (object ["title" .= ("두 번째" :: String)]))
      _ <- put "/todos/1/status" (Aeson.encode (object ["status" .= ("done" :: String)]))
      get "/todos?status=done"
    fmap lengthOf (jsonBody response) `shouldBe` Just 1

  it "tag 질의 매개변수로 걸러낼 수 있다" $ do
    response <- withApi $ do
      _ <-
        post
          "/todos"
          (Aeson.encode (object ["title" .= ("일" :: String), "tags" .= (["work"] :: [String])]))
      _ <- post "/todos" (Aeson.encode (object ["title" .= ("이" :: String)]))
      get "/todos?tag=work"
    fmap lengthOf (jsonBody response) `shouldBe` Just 1

  it "오류 응답은 code와 message를 모두 담는다" $ do
    response <- withApi (get "/todos/999")
    fmap (sort . keysOf) (jsonBody response) `shouldBe` Just ["code", "message"]

-- 보조 함수 ------------------------------------------------------------------

fieldOf :: Aeson.Key -> Value -> Maybe Value
fieldOf key (Object o) = KeyMap.lookup key o
fieldOf _ _ = Nothing

keysOf :: Value -> [Aeson.Key]
keysOf (Object o) = KeyMap.keys o
keysOf _ = []

lengthOf :: Value -> Int
lengthOf (Array xs) = length xs
lengthOf _ = -1
