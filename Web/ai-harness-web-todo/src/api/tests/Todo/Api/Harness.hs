{-# LANGUAGE OverloadedStrings #-}

-- | HTTP 테스트를 위한 최소 도구입니다.
--
-- 실제 포트를 열지 않고 WAI 애플리케이션에 직접 요청을 흘려보냅니다. 덕분에
-- 테스트가 포트 충돌이나 대기 없이 결정적으로 실행됩니다.
module Todo.Api.Harness (
  withApi,
  get,
  post,
  patch,
  put,
  delete,
  jsonBody,
  statusOf,
) where

import qualified Data.Aeson as Aeson
import qualified Data.ByteString.Lazy as LBS
import Data.Text (Text)
import qualified Data.Text.Encoding as TE
import Network.HTTP.Types (Method, hContentType, statusCode)
import Network.Wai (Request (..), defaultRequest)
import Network.Wai.Test (
  SRequest (..),
  SResponse (..),
  Session,
  request,
  runSession,
  setPath,
  srequest,
 )
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Todo.Api.Server (application)
import Todo.Store.Sqlite (withStore)

-- | 빈 임시 데이터베이스 위에서 세션을 실행합니다.
withApi :: Session a -> IO a
withApi session =
  withSystemTempDirectory "api-test" $ \dir ->
    withStore (dir </> "todo.db") $ \conn ->
      runSession session (application conn)

buildRequest :: Method -> Text -> Request
buildRequest method path =
  setPath
    defaultRequest
      { requestMethod = method
      , requestHeaders = [(hContentType, "application/json")]
      }
    (TE.encodeUtf8 path)

-- | 본문 없는 GET 요청입니다.
get :: Text -> Session SResponse
get path = request (buildRequest "GET" path)

-- | 본문 없는 DELETE 요청입니다.
delete :: Text -> Session SResponse
delete path = request (buildRequest "DELETE" path)

post :: Text -> LBS.ByteString -> Session SResponse
post = withBody "POST"

patch :: Text -> LBS.ByteString -> Session SResponse
patch = withBody "PATCH"

put :: Text -> LBS.ByteString -> Session SResponse
put = withBody "PUT"

withBody :: Method -> Text -> LBS.ByteString -> Session SResponse
withBody method path body = srequest (SRequest (buildRequest method path) body)

-- | 응답 본문을 JSON으로 해석합니다.
jsonBody :: (Aeson.FromJSON a) => SResponse -> Maybe a
jsonBody = Aeson.decode . simpleBody

-- | 응답의 HTTP 상태 코드입니다.
statusOf :: SResponse -> Int
statusOf = statusCode . simpleStatus
