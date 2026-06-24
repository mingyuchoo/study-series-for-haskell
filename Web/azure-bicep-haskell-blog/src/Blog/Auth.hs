-- | 인증: 비밀번호 해싱(bcrypt)과 서명 쿠키 기반 무상태 세션.
--
-- 세션은 서버에 상태를 두지 않는다. 쿠키 값은 @uid:만료에폭@ 페이로드와 그
-- 페이로드의 HMAC-SHA256 서명으로 이루어진다(미리보기 토큰과 같은 비밀키 재사용).
-- 매 요청에서 서명과 만료를 검증해 사용자를 복원하므로 위조가 불가능하다.
--
-- 'AuthUser' 생성자는 노출하지 않는다. 오직 'resolveSession'(쿠키 검증 +
-- 사용자 조회)만이 'AuthUser' 를 생산하므로, "인증된 사용자"는 타입 차원에서
-- 검증을 거친 값임이 보장된다.
module Blog.Auth
  ( -- * 비밀번호
    hashPassword
  , verifyPassword
    -- * 세션
  , AuthUser
  , authedUser
  , makeSessionValue
  , resolveSession
    -- * 쿠키
  , sessionCookieName
  , renderSessionSetCookie
  , renderClearSetCookie
  , sessionTtlSeconds
    -- * 서명 헬퍼
  , hmacHex
  ) where

import Crypto.Hash.Algorithms (SHA256)
import Crypto.KDF.BCrypt qualified as BCrypt
import Crypto.MAC.HMAC (HMAC, hmac, hmacGetDigest)
import Data.Bits (xor, (.|.))
import Data.ByteString (ByteString)
import Data.ByteString qualified as BS
import Data.ByteString.Builder (toLazyByteString)
import Data.List (foldl')
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Encoding (decodeUtf8, encodeUtf8)
import Data.Text.Lazy qualified as TL
import Data.Text.Lazy.Encoding qualified as TLE
import Data.Time (UTCTime)
import Data.Time.Clock (secondsToDiffTime)
import Data.Time.Clock.POSIX (utcTimeToPOSIXSeconds)
import Text.Read (readMaybe)
import Web.Cookie
  ( SetCookie
  , defaultSetCookie
  , renderSetCookie
  , sameSiteLax
  , setCookieHttpOnly
  , setCookieMaxAge
  , setCookieName
  , setCookiePath
  , setCookieSameSite
  , setCookieValue
  )

import Blog.User (User (..))

-- | 검증된 세션에서만 만들어지는 "인증된 사용자". 생성자는 비공개다.
newtype AuthUser = AuthUser User

-- | 인증된 사용자의 도메인 'User' 를 꺼낸다.
authedUser :: AuthUser -> User
authedUser (AuthUser u) = u

-- 비밀번호 ----------------------------------------------------------------

-- | 평문 비밀번호를 bcrypt(cost 12)로 해시한다.
hashPassword :: Text -> IO Text
hashPassword pw =
  decodeUtf8 <$> (BCrypt.hashPassword 12 (encodeUtf8 pw) :: IO ByteString)

-- | 평문 비밀번호가 저장된 bcrypt 해시와 일치하는지 검사한다(상수 시간 비교).
verifyPassword :: Text -> Text -> Bool
verifyPassword pw hash =
  BCrypt.validatePassword (encodeUtf8 pw) (encodeUtf8 hash)

-- 세션 -------------------------------------------------------------------

-- | 세션 유효 기간(초). 7일.
sessionTtlSeconds :: Int
sessionTtlSeconds = 7 * 24 * 60 * 60

-- | 서명된 세션 쿠키 값을 만든다: @uid:만료에폭.서명@.
makeSessionValue :: ByteString -> Int -> UTCTime -> Text
makeSessionValue secret uid expiry =
  payload <> "." <> hmacHex secret payload
  where
    payload = T.pack (show uid) <> ":" <> T.pack (show (epochOf expiry))

-- | 쿠키 값을 검증하고, 유효하면 사용자 조회로 'AuthUser' 를 복원한다.
--
-- 서명 불일치·형식 오류·만료면 'Nothing'. 사용자 조회는 인자로 주입받아
-- 이 모듈이 저장소 구현에 의존하지 않게 한다.
resolveSession
  :: ByteString
  -- ^ 비밀키
  -> UTCTime
  -- ^ 현재 시각
  -> (Int -> IO (Maybe User))
  -- ^ id로 사용자 조회
  -> Text
  -- ^ 쿠키 값
  -> IO (Maybe AuthUser)
resolveSession secret now lookupUser cookieVal =
  case verifySessionValue secret now cookieVal of
    Nothing  -> pure Nothing
    Just uid -> fmap (fmap AuthUser) (lookupUser uid)

-- | 쿠키 값을 검증해 (유효·미만료) 사용자 id를 돌려준다.
verifySessionValue :: ByteString -> UTCTime -> Text -> Maybe Int
verifySessionValue secret now cookieVal = do
  (payload, sig) <- splitLast '.' cookieVal
  if hmacHex secret payload `constEqText` sig
    then do
      (uidT, expT) <- splitLast ':' payload
      uid <- readMaybe (T.unpack uidT)
      exp' <- readMaybe (T.unpack expT) :: Maybe Integer
      if exp' > epochOf now then Just uid else Nothing
    else Nothing

-- 쿠키 ------------------------------------------------------------------

-- | 세션 쿠키 이름.
sessionCookieName :: ByteString
sessionCookieName = "blogsession"

-- | 로그인 시 설정할 Set-Cookie 헤더 값.
renderSessionSetCookie :: Text -> TL.Text
renderSessionSetCookie val =
  renderCookieText
    (baseCookie (encodeUtf8 val))
      { setCookieMaxAge = Just (secondsToDiffTime (fromIntegral sessionTtlSeconds))
      }

-- | 로그아웃 시 쿠키를 즉시 만료시키는 Set-Cookie 헤더 값.
renderClearSetCookie :: TL.Text
renderClearSetCookie =
  renderCookieText
    (baseCookie "")
      { setCookieMaxAge = Just (secondsToDiffTime 0)
      }

baseCookie :: ByteString -> SetCookie
baseCookie value =
  defaultSetCookie
    { setCookieName = sessionCookieName
    , setCookieValue = value
    , setCookiePath = Just "/"
    , setCookieHttpOnly = True
    , setCookieSameSite = Just sameSiteLax
    -- 참고: 운영(HTTPS)에서는 setCookieSecure = True 를 더해야 한다.
    }

renderCookieText :: SetCookie -> TL.Text
renderCookieText = TLE.decodeUtf8 . toLazyByteString . renderSetCookie

-- 내부 헬퍼 --------------------------------------------------------------

-- | 페이로드를 비밀키로 HMAC-SHA256 서명(16진수)한다.
--   세션 서명뿐 아니라 가입 인증 코드 해시에도 재사용한다(키는 도메인별로 분리).
hmacHex :: ByteString -> Text -> Text
hmacHex key payload = T.pack (show (hmacGetDigest mac))
  where
    mac :: HMAC SHA256
    mac = hmac key (encodeUtf8 payload)

epochOf :: UTCTime -> Integer
epochOf = floor . utcTimeToPOSIXSeconds

-- | 구분자의 __마지막__ 출현을 기준으로 둘로 나눈다(서명 분리용).
splitLast :: Char -> Text -> Maybe (Text, Text)
splitLast c t = case T.breakOnEnd (T.singleton c) t of
  (pre, post)
    | T.null pre -> Nothing -- 구분자 없음
    | otherwise -> Just (T.dropEnd 1 pre, post)

-- | 서명 비교용 상수 시간 비교(타이밍 누출 방지).
--
-- 서명은 항상 64자 고정 길이 16진수라 길이는 비밀이 아니다. 길이가 같으면
-- 모든 바이트를 XOR-누적해 조기 종료 없이 비교한다.
constEqText :: Text -> Text -> Bool
constEqText a b =
  BS.length xs == BS.length ys
    && foldl' (\acc i -> acc .|. xor (BS.index xs i) (BS.index ys i)) 0 [0 .. BS.length xs - 1]
      == 0
  where
    xs = encodeUtf8 a
    ys = encodeUtf8 b
