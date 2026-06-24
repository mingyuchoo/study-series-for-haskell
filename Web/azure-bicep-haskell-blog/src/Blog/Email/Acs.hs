-- | Azure Communication Services(ACS) Email 발송 어댑터.
--
-- 'Blog.Email' 의 'EmailSender' 포트를 ACS Email REST API 로 구현한다. 연결 문자열의
-- 액세스 키로 ACS HMAC-SHA256 서명을 만들어 인증한다(별도 SDK 없이 직접 호출).
--
-- 서명 규약: @{VERB}\n{path?query}\n{x-ms-date};{host};{content-sha256}@ 를
-- base64(HMAC-SHA256(base64decode(accessKey), …)) 로 서명하고
-- @Authorization: HMAC-SHA256 SignedHeaders=x-ms-date;host;x-ms-content-sha256&Signature=…@.
module Blog.Email.Acs
  ( AcsConfig (..)
  , parseAcsConnectionString
  , acsEmailSender
  ) where

import Control.Exception (SomeException, try)
import Crypto.Hash (Digest, hash)
import Crypto.Hash.Algorithms (SHA256)
import Crypto.MAC.HMAC (HMAC, hmac)
import Data.ByteArray.Encoding (Base (Base64), convertFromBase, convertToBase)
import Data.ByteString (ByteString)
import Data.ByteString.Char8 qualified as BS8
import Data.ByteString.Lazy.Char8 qualified as LBS8
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Encoding (encodeUtf8)
import Data.Time (getCurrentTime)
import Data.Time.Format (defaultTimeLocale, formatTime)
import Network.HTTP.Client
  ( Manager
  , RequestBody (RequestBodyBS)
  , httpLbs
  , method
  , parseRequest
  , path
  , queryString
  , requestBody
  , requestHeaders
  , responseBody
  , responseStatus
  )
import Network.HTTP.Types.Status (statusCode)
import System.IO (hPutStrLn, stderr)

import Blog.Email (Code (..), EmailSender (..))

-- | ACS 호출에 필요한 최소 설정.
data AcsConfig = AcsConfig
  { acsHost   :: ByteString
    -- ^ 예: @acs-xxxx.communication.azure.com@ (스킴·슬래시 없음).
  , acsKey    :: ByteString
    -- ^ base64 디코딩한 HMAC 키 바이트.
  , acsSender :: Text
    -- ^ 발신자 주소(예: @donotreply\@....azurecomm.net@).
  }

-- 송신 경로/쿼리 — 서명 문자열과 실제 요청에서 byte 단위로 동일해야 한다.
apiPath :: ByteString
apiPath = "/emails:send"

apiQuery :: ByteString
apiQuery = "api-version=2023-03-31"

-- | @endpoint=https://…;accesskey=…@ 형식의 연결 문자열과 발신자 주소로 설정을 만든다.
parseAcsConnectionString :: Text -> Text -> Either String AcsConfig
parseAcsConnectionString conn sender =
  case (lookup "endpoint" kvs, lookup "accesskey" kvs) of
    (Just ep, Just ak) -> do
      keyBytes <- convertFromBase Base64 (encodeUtf8 (T.strip ak))
      let epClean = T.dropWhileEnd (== '/') (T.strip ep)
          hostT = T.dropWhileEnd (== '/') (stripScheme epClean)
      Right
        AcsConfig
          { acsHost = encodeUtf8 hostT
          , acsKey = keyBytes
          , acsSender = sender
          }
    _ -> Left "ACS 연결 문자열에 endpoint/accesskey 가 없습니다."
  where
    kvs =
      [ (T.toLower (T.strip k), T.drop 1 v)
      | seg <- T.splitOn ";" conn
      , let (k, v) = T.breakOn "=" seg
      , not (T.null v)
      ]
    stripScheme t = fromMaybe t (T.stripPrefix "https://" t)

-- | ACS Email 로 인증 코드를 발송하는 'EmailSender'.
--   실패는 stderr 로 로깅하고 예외를 삼킨다(가입 요청 흐름을 막지 않도록 — 사용자는 재전송 가능).
acsEmailSender :: Manager -> AcsConfig -> EmailSender
acsEmailSender mgr cfg = EmailSender $ \email (Code code) -> do
  let subject = "회원가입 인증 코드"
      plain =
        "인증 코드: "
          <> code
          <> "\n\n10분 안에 입력해 주세요. 본인이 요청하지 않았다면 이 메일을 무시하세요."
      bodyBs = encodeUtf8 (renderBody (acsSender cfg) email subject plain)
      contentHash = convertToBase Base64 (hash bodyBs :: Digest SHA256) :: ByteString
  now <- getCurrentTime
  let dateBs = BS8.pack (formatTime defaultTimeLocale "%a, %d %b %Y %H:%M:%S GMT" now)
      stringToSign =
        BS8.intercalate
          "\n"
          [ "POST"
          , apiPath <> "?" <> apiQuery
          , BS8.intercalate ";" [dateBs, acsHost cfg, contentHash]
          ]
      signature = convertToBase Base64 (hmac (acsKey cfg) stringToSign :: HMAC SHA256) :: ByteString
      authHdr =
        "HMAC-SHA256 SignedHeaders=x-ms-date;host;x-ms-content-sha256&Signature=" <> signature
  result <- try $ do
    base <- parseRequest ("https://" <> BS8.unpack (acsHost cfg))
    let req =
          base
            { method = "POST"
            , path = apiPath
            , queryString = "?" <> apiQuery
            , requestHeaders =
                [ ("Content-Type", "application/json")
                , ("x-ms-date", dateBs)
                , ("x-ms-content-sha256", contentHash)
                , ("Authorization", authHdr)
                ]
            , requestBody = RequestBodyBS bodyBs
            }
    httpLbs req mgr
  case result of
    Left (e :: SomeException) ->
      hPutStrLn stderr ("[email] ACS 전송 예외: " <> show e)
    Right resp ->
      let sc = statusCode (responseStatus resp)
       in if sc >= 200 && sc < 300
            then pure ()
            else
              hPutStrLn
                stderr
                ("[email] ACS 전송 실패 status=" <> show sc <> " body=" <> LBS8.unpack (responseBody resp))

-- | ACS Email 요청 JSON 본문(고정 형태, 문자열은 이스케이프).
renderBody :: Text -> Text -> Text -> Text -> Text
renderBody sender to subject plain =
  T.concat
    [ "{\"senderAddress\":"
    , jsonStr sender
    , ",\"content\":{\"subject\":"
    , jsonStr subject
    , ",\"plainText\":"
    , jsonStr plain
    , "}"
    , ",\"recipients\":{\"to\":[{\"address\":"
    , jsonStr to
    , "}]}}"
    ]

-- | 최소 JSON 문자열 이스케이프(따옴표로 감싼다).
jsonStr :: Text -> Text
jsonStr t = "\"" <> T.concatMap esc t <> "\""
  where
    esc '"'  = "\\\""
    esc '\\' = "\\\\"
    esc '\n' = "\\n"
    esc '\r' = "\\r"
    esc '\t' = "\\t"
    esc c    = T.singleton c
