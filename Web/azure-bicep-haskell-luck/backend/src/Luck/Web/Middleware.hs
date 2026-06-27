{-# LANGUAGE OverloadedStrings #-}

-- | WAI 미들웨어 모음 (보안 헤더, CORS, 인증 엔드포인트 rate limiting).
--   Main 의 조립부를 얇게 유지하기 위해 한곳에 모은다.
module Luck.Web.Middleware
    ( RateLimiter
    , corsMiddleware
    , newRateLimiter
    , rateLimit
    , securityHeaders
    ) where

import           Data.Aeson                  (encode, object, (.=))
import           Data.ByteString             (ByteString)
import qualified Data.ByteString.Char8       as BS
import           Data.IORef                  (IORef, atomicModifyIORef', newIORef)
import qualified Data.Map.Strict             as Map
import           Data.Text                   (Text)
import           Data.Time.Clock
    ( NominalDiffTime
    , UTCTime
    , diffUTCTime
    , getCurrentTime
    )
import           Network.HTTP.Types          (hContentType, status429)
import           Network.HTTP.Types.Header    (Header)
import           Network.Wai
import           Network.Wai.Middleware.Cors
    ( CorsResourcePolicy (..)
    , cors
    , simpleCorsResourcePolicy
    )

-- ── 보안 응답 헤더 ──────────────────────────────────────────────────────────

-- | 응답에 보안 헤더를 덧붙인다. 이 서버는 SPA 문서와 JSON API를 같은 출처에서
--   함께 제공하므로, CSP는 동일 출처('self') 자산과 Google Fonts 만 허용한다.
--   (@default-src 'none'@ 으로 잠그면 SPA 가 자기 JS/CSS/폰트를 못 불러온다.)
--     - script-src  'self'                : Vite 번들 (/assets/*.js)
--     - style-src   'self' + googleapis   : 번들 CSS + Google Fonts 스타일시트
--                   'unsafe-inline'       : 런타임 주입 인라인 스타일/style 속성 허용
--     - font-src    gstatic               : 실제 폰트 파일
--     - connect-src 'self'                : /api/* fetch/XHR
--   HSTS는 운영 모드에서만 (TLS 종단 뒤에서 의미가 있다).
securityHeaders :: Bool -> Middleware
securityHeaders isProd app req respond =
  app req (respond . mapResponseHeaders addSecure)
  where
    addSecure existing =
      existing ++ filter (\(k, _) -> k `notElem` map fst existing) secure
    secure :: [Header]
    secure = base ++ [hsts | isProd]
    base =
      [ ("X-Content-Type-Options", "nosniff")
      , ("X-Frame-Options", "DENY")
      , ("Referrer-Policy", "no-referrer")
      , ("Content-Security-Policy", csp)
      ]
    csp =
      "default-src 'self'; \
      \script-src 'self'; \
      \style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; \
      \font-src 'self' https://fonts.gstatic.com data:; \
      \img-src 'self' data:; \
      \connect-src 'self'; \
      \object-src 'none'; \
      \base-uri 'self'; \
      \frame-ancestors 'none'"
    hsts = ("Strict-Transport-Security", "max-age=31536000; includeSubDomains")

-- ── CORS ────────────────────────────────────────────────────────────────────

-- | 허용 오리진 화이트리스트로 CORS를 적용한다.
--   목록이 비어 있으면 모든 오리진 허용(개발 편의) — 운영에선 반드시 지정한다.
corsMiddleware :: [ByteString] -> Middleware
corsMiddleware origins = cors (const (Just policy))
  where
    policy =
      simpleCorsResourcePolicy
        { corsOrigins = case origins of
            [] -> Nothing
            os -> Just (os, True)
        , corsRequestHeaders = ["Authorization", "Content-Type"]
        , corsMethods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
        }

-- ── Rate limiting (인증 엔드포인트) ─────────────────────────────────────────

-- | IP별 최근 요청 시각 목록.
type RateLimiter = IORef (Map.Map ByteString [UTCTime])

-- | 윈도(초)와 윈도당 최대 허용 횟수.
windowSecs :: NominalDiffTime
windowSecs = 60

maxHits :: Int
maxHits = 10

newRateLimiter :: IO RateLimiter
newRateLimiter = newIORef Map.empty

-- | @/api/auth/*@ 요청에 IP 기준 슬라이딩 윈도 제한을 적용한다.
--   초과하면 429를 돌려준다. 그 외 경로는 그대로 통과.
rateLimit :: RateLimiter -> Middleware
rateLimit ref app req respond
  | isAuthPath (pathInfo req) = do
      now <- getCurrentTime
      allowed <- atomicModifyIORef' ref (step now (clientKey req))
      if allowed then app req respond else respond tooMany
  | otherwise = app req respond

-- | 윈도 밖 기록은 버리고, 한도 미만이면 현재 시각을 추가(허용), 아니면 거부.
step :: UTCTime -> ByteString -> Map.Map ByteString [UTCTime] -> (Map.Map ByteString [UTCTime], Bool)
step now key m =
  let recent = filter (\t -> diffUTCTime now t < windowSecs) (Map.findWithDefault [] key m)
   in if length recent >= maxHits
        then (Map.insert key recent m, False)
        else (Map.insert key (now : recent) m, True)

isAuthPath :: [Text] -> Bool
isAuthPath ("api" : "auth" : _) = True
isAuthPath _                    = False

-- | 클라이언트 식별 키. 프록시 뒤를 고려해 X-Forwarded-For 첫 IP를 우선 사용.
clientKey :: Request -> ByteString
clientKey req =
  case lookup "X-Forwarded-For" (requestHeaders req) of
    Just v  -> BS.takeWhile (/= ',') (BS.dropWhile (== ' ') v)
    Nothing -> BS.pack (show (remoteHost req))

tooMany :: Response
tooMany =
  responseLBS
    status429
    [(hContentType, "application/json;charset=utf-8")]
    (encode (object ["message" .= ("요청이 너무 많습니다. 잠시 후 다시 시도하세요." :: Text)]))
