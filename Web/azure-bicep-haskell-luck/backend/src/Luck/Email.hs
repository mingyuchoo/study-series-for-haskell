{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}

-- | 회원가입 인증번호 이메일 발송.
--
--   Azure Communication Services(ACS) Email REST API 를 직접 호출한다.
--   인증은 액세스 키(connection string) 기반 HMAC-SHA256 서명 스킴을 사용한다
--   (Azure SDK 가 ACS 데이터플레인에 쓰는 것과 동일한 방식).
--
--   ACS_CONNECTION_STRING / ACS_SENDER_ADDRESS 가 비어 있으면 비활성 상태가 되어
--   코드를 콘솔에 출력만 한다(로컬 개발 폴백).
module Luck.Email
    ( EmailSender
    , newEmailSender
    , sendVerificationCode
    ) where

import           Control.Exception         (SomeException, try)
import           Crypto.Hash               (SHA256 (..), hashWith)
import           Crypto.MAC.HMAC           (HMAC, hmac)
import           Data.Aeson                (Value, encode, object, (.=))
import qualified Data.ByteArray            as BA
import           Data.ByteString           (ByteString)
import qualified Data.ByteString           as BS
import qualified Data.ByteString.Base64    as B64
import qualified Data.ByteString.Char8     as BC
import qualified Data.ByteString.Lazy      as BL
import           Data.Text                 (Text)
import qualified Data.Text                 as T
import qualified Data.Text.Encoding        as TE
import           Data.Time                 (getCurrentTime)
import           Data.Time.Format          (defaultTimeLocale, formatTime)
import           Network.HTTP.Client
    ( Manager
    , Request (..)
    , RequestBody (RequestBodyBS)
    , Response
    , httpLbs
    , parseRequest
    , responseBody
    , responseStatus
    )
import           Network.HTTP.Client.TLS   (newTlsManager)
import           Network.HTTP.Types.Status (statusCode)

-- | 발송기. 비활성(콘솔 폴백) 또는 ACS 설정 완료 상태.
data EmailSender
  = EmailDisabled
  | EmailAcs
      { acsHost    :: ByteString
        -- ^ 호스트(예: foo.communication.azure.com). HMAC 서명에 쓰인다.
      , acsBaseUrl :: String
        -- ^ https://foo.communication.azure.com (끝의 / 제거)
      , acsKey     :: ByteString
        -- ^ base64 디코딩한 액세스 키
      , acsSender  :: Text
        -- ^ 발신 주소(DoNotReply@...azurecomm.net)
      , acsManager :: Manager
      }

-- | 연결 문자열 + 발신 주소로 발송기를 만든다. 둘 중 하나라도 비면 비활성.
newEmailSender :: ByteString -> Text -> IO EmailSender
newEmailSender connStr sender
  | BS.null connStr || T.null sender = pure EmailDisabled
  | otherwise =
      case parseConn connStr of
        Nothing -> pure EmailDisabled
        Just (endpoint, key) -> do
          mgr <- newTlsManager
          pure
            EmailAcs
              { acsHost = TE.encodeUtf8 (hostOf endpoint)
              , acsBaseUrl = T.unpack (T.dropWhileEnd (== '/') endpoint)
              , acsKey = key
              , acsSender = sender
              , acsManager = mgr
              }

-- | 인증번호를 발송한다. 성공 시 @Right ()@, 실패 시 사유를 @Left@ 로.
--   비활성 상태에서는 콘솔에 출력하고 성공으로 간주한다.
sendVerificationCode :: EmailSender -> Text -> Text -> Text -> IO (Either Text ())
sendVerificationCode EmailDisabled toAddr _name code = do
  putStrLn
    ("[SIGNUP][dev] ACS 미설정 — verification code for "
       <> T.unpack toAddr
       <> ": "
       <> T.unpack code)
  pure (Right ())
sendVerificationCode EmailAcs {..} toAddr name code = do
  now <- getCurrentTime
  let path = "/emails:send?api-version=2023-03-31"
      url = acsBaseUrl <> path
      body = BL.toStrict (encode (emailPayload acsSender toAddr name code))
      contentHash = b64 (sha256 body)
      date = BC.pack (formatTime defaultTimeLocale "%a, %d %b %Y %H:%M:%S GMT" now)
      -- VERB \n path+query \n date;host;contentHash
      stringToSign =
        BS.intercalate
          "\n"
          [ "POST"
          , BC.pack path
          , BS.intercalate ";" [date, acsHost, contentHash]
          ]
      sig = b64 (hmacSha256 acsKey stringToSign)
      authz =
        "HMAC-SHA256 SignedHeaders=x-ms-date;host;x-ms-content-sha256&Signature="
          <> sig
  ereq <- try (parseRequest ("POST " <> url)) :: IO (Either SomeException Request)
  case ereq of
    Left e -> pure (Left ("요청 생성 실패: " <> T.pack (show e)))
    Right req0 -> do
      -- host 헤더는 http-client 가 URL 에서 자동 생성하므로 명시하지 않는다
      -- (서명의 host 값과 실제 전송되는 Host 가 일치해야 한다).
      let req =
            req0
              { method = "POST"
              , requestHeaders =
                  [ ("x-ms-date", date)
                  , ("x-ms-content-sha256", contentHash)
                  , ("Authorization", authz)
                  , ("Content-Type", "application/json")
                  ]
              , requestBody = RequestBodyBS body
              }
      eresp <-
        try (httpLbs req acsManager) :: IO (Either SomeException (Response BL.ByteString))
      case eresp of
        Left e -> pure (Left ("전송 실패: " <> T.pack (show e)))
        Right resp ->
          let sc = statusCode (responseStatus resp)
           in if sc >= 200 && sc < 300
                then pure (Right ())
                else
                  pure
                    ( Left
                        ( "ACS 응답 "
                            <> T.pack (show sc)
                            <> ": "
                            <> TE.decodeUtf8 (BL.toStrict (responseBody resp))
                        )
                    )

-- ── 페이로드 ────────────────────────────────────────────────────────────────

emailPayload :: Text -> Text -> Text -> Text -> Value
emailPayload sender toAddr name code =
  object
    [ "senderAddress" .= sender
    , "content"
        .= object
          [ "subject" .= ("[운 運] 회원가입 인증번호 " <> code :: Text)
          , "plainText" .= plain
          , "html" .= html
          ]
    , "recipients"
        .= object
          [ "to" .= [object ["address" .= toAddr, "displayName" .= name]]
          ]
    ]
  where
    greeting = if T.null name then "안녕하세요," else name <> "님, 안녕하세요."
    plain =
      greeting
        <> "\n\n회원가입 인증번호는 "
        <> code
        <> " 입니다.\n5분 안에 화면에 입력해 주세요.\n\n본인이 요청하지 않았다면 이 메일을 무시하세요."
    html =
      "<div style=\"font-family:sans-serif;max-width:480px;margin:0 auto;padding:24px\">"
        <> "<p style=\"font-size:15px;color:#333\">"
        <> greeting
        <> "</p>"
        <> "<p style=\"font-size:15px;color:#333\">회원가입 인증번호입니다. 5분 안에 입력해 주세요.</p>"
        <> "<p style=\"font-size:34px;font-weight:700;letter-spacing:8px;margin:20px 0;color:#000\">"
        <> code
        <> "</p>"
        <> "<p style=\"font-size:12px;color:#999\">본인이 요청하지 않았다면 이 메일을 무시하세요.</p>"
        <> "</div>"

-- ── 암호 헬퍼 ───────────────────────────────────────────────────────────────

sha256 :: ByteString -> ByteString
sha256 = BA.convert . hashWith SHA256

hmacSha256 :: ByteString -> ByteString -> ByteString
hmacSha256 key msg = BA.convert (hmac key msg :: HMAC SHA256)

b64 :: ByteString -> ByteString
b64 = B64.encode

-- ── 연결 문자열 파싱 ─────────────────────────────────────────────────────────

-- | "endpoint=https://x.communication.azure.com/;accesskey=BASE64" 를
--   (endpoint, 디코딩한 키) 로 분해한다.
parseConn :: ByteString -> Maybe (Text, ByteString)
parseConn bs = do
  let parts = T.splitOn ";" (TE.decodeUtf8 bs)
      kv =
        [ (T.toLower (T.strip k), T.drop 1 v)
        | p <- parts
        , let (k, v) = T.break (== '=') p
        , not (T.null v)
        ]
  ep <- lookup "endpoint" kv
  keyB64 <- lookup "accesskey" kv
  key <- either (const Nothing) Just (B64.decode (TE.encodeUtf8 (T.strip keyB64)))
  pure (T.strip ep, key)

-- | "https://host/..." 에서 host 만 추출.
hostOf :: Text -> Text
hostOf ep = T.takeWhile (/= '/') (T.drop 2 (snd (T.breakOn "//" ep)))
