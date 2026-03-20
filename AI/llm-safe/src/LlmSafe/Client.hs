{-# LANGUAGE OverloadedStrings #-}

-- | LLM API 호출 모듈 — 비결정적 영역.
--
--   Azure OpenAI API를 호출하여 LLM 응답을 가져온다.
--   이 모듈의 모든 함수는 'IO' 모나드 안에 있으므로,
--   타입 시그니처만으로 비결정성이 드러난다.
module LlmSafe.Client
    ( -- * LLM 호출 (비결정적 영역)
      callLlm
    , callLlmN
    , callLlmWithRetry
      -- * 모의(Mock) 클라이언트
    , mockCallLlm
    ) where

import           Control.Concurrent.Async  (mapConcurrently)

import           Data.Aeson                (Value (..), object, (.=))
import qualified Data.Aeson                as Aeson
import qualified Data.Aeson.KeyMap         as KM
import qualified Data.ByteString.Char8     as BS8
import qualified Data.ByteString.Lazy      as LBS
import qualified Data.Text                 as T

import           LlmSafe.Types             (Confidence (..), LlmConfig (..),
                                            LlmError (..), LlmResponse (..))

import           Network.HTTP.Client       (RequestBody (..), httpLbs, method,
                                            newManager, parseRequest,
                                            requestBody, requestHeaders,
                                            responseBody, responseStatus)
import           Network.HTTP.Client.TLS   (tlsManagerSettings)
import           Network.HTTP.Types.Status (statusCode)

-- | Azure OpenAI Chat Completions API를 호출한다.
--
--   'IO' 모나드 안에 있으므로 비결정적임이 타입에 드러난다.
--   'logger'를 통해 진행 메시지를 전달한다 (CLI: 'putStrLn', TUI: BChan 기록).
callLlm :: LlmConfig -> (String -> IO ()) -> String -> IO (LlmResponse String)
callLlm config logger prompt = do
  let url =
        configEndpoint config
          <> "/openai/deployments/"
          <> configModelId config
          <> "/chat/completions?api-version="
          <> configApiVersion config

  logger $ "[LLM 호출] 모델: " <> configModelId config
  logger $ "[LLM 호출] 프롬프트: " <> take 50 prompt <> "..."

  manager <- newManager tlsManagerSettings
  initReq <- parseRequest url

  let reqBody =
        object
          [ "messages"
              .= [ object
                     [ "role" .= ("user" :: String)
                     , "content" .= prompt
                     ]
                 ]
          , "max_completion_tokens" .= (1024 :: Int)
          ]

  let req =
        initReq
          { method = "POST"
          , requestHeaders =
              [ ("Content-Type", "application/json")
              , ("api-key", BS8.pack (configApiKey config))
              ]
          , requestBody = RequestBodyLBS (Aeson.encode reqBody)
          }

  resp <- httpLbs req manager
  let status = statusCode (responseStatus resp)
  let body = responseBody resp

  if status /= 200
    then do
      logger $ "[LLM 에러] HTTP " <> show status
      logger $ "[LLM 에러] " <> take 200 (show body)
      pure
        LlmResponse
          { rawContent = "Error: HTTP " <> show status
          , confidence = Low
          , modelId = configModelId config
          , promptHash = show (length prompt)
          }
    else case extractContent body of
      Nothing -> do
        logger "[LLM 에러] 응답 파싱 실패"
        pure
          LlmResponse
            { rawContent = "Error: 응답 파싱 실패"
            , confidence = Low
            , modelId = configModelId config
            , promptHash = show (length prompt)
            }
      Just content -> do
        logger $ "[LLM 응답] " <> take 100 content
        pure
          LlmResponse
            { rawContent = content
            , confidence = High
            , modelId = configModelId config
            , promptHash = show (length prompt)
            }

-- | Azure OpenAI 응답 JSON에서 content 문자열을 추출한다.
extractContent :: LBS.ByteString -> Maybe String
extractContent bs = do
  val <- Aeson.decode bs :: Maybe Value
  case val of
    Object obj -> do
      Array choices <- KM.lookup "choices" obj
      let choiceList = foldr (:) [] choices
      case choiceList of
        (Object choice : _) -> do
          Object msg <- KM.lookup "message" choice
          String txt <- KM.lookup "content" msg
          pure (T.unpack txt)
        _ -> Nothing
    _ -> Nothing

-- | 재시도가 포함된 LLM 호출.
--
--   신뢰도가 설정의 최소 요구 수준 미만이면 재시도한다.
--   최대 재시도 횟수를 초과하면 'RetryExhausted'를 반환한다.
callLlmWithRetry :: LlmConfig -> (String -> IO ()) -> String -> IO (Either LlmError (LlmResponse String))
callLlmWithRetry config logger prompt = go (configMaxRetries config)
 where
  go 0 = pure $ Left (RetryExhausted (configMaxRetries config))
  go n = do
    response <- callLlm config logger prompt
    if confidence response < configMinConfidence config
      then do
        logger $ "[재시도] 신뢰도 부족, 남은 횟수: " <> show (n - 1)
        go (n - 1)
      else pure $ Right response

-- | N개의 에이전트를 병렬로 실행하여 응답 목록을 수집한다.
--
--   각 에이전트는 독립적으로 LLM을 호출하며, 'mapConcurrently'로 동시 실행된다.
--   합의 기반 검증('LlmSafe.Verify.verifyByConsensus')의 입력으로 사용된다.
callLlmN :: LlmConfig -> (String -> IO ()) -> Int -> String -> IO [LlmResponse String]
callLlmN config logger n prompt =
  mapConcurrently runAgent [1 .. n]
  where
    runAgent i =
      let agentLogger msg = logger $ "[에이전트 " <> show i <> "/" <> show n <> "] " <> msg
      in  callLlm config agentLogger prompt

-- | 모의 LLM 호출. 테스트용으로 순수한 응답을 생성한다.
mockCallLlm :: Confidence -> String -> String -> LlmResponse String
mockCallLlm conf model content =
  LlmResponse
    { rawContent = content
    , confidence = conf
    , modelId = model
    , promptHash = show (length content)
    }
