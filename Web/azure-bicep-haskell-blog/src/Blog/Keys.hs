-- | 마스터 비밀에서 용도별 서명 키를 도메인 분리해 파생한다.
--
-- 미리보기 토큰과 세션 쿠키는 서로 다른 보안 도메인이다. 하나의 마스터 비밀을
-- 양쪽에 그대로 쓰는 대신, 라벨로 분리한 서브키를 HMAC 으로 파생해 각 도메인이
-- 자기 키만 보게 한다(한 도메인의 서명을 다른 도메인에 재사용·교차할 수 없음).
module Blog.Keys
  ( AppKeys (..)
  , deriveKeys
  ) where

import Crypto.Hash.Algorithms (SHA256)
import Crypto.MAC.HMAC (HMAC, hmac, hmacGetDigest)
import Data.ByteString (ByteString)
import Data.ByteString.Char8 qualified as BS8

-- | 용도별로 분리된 서명 키.
data AppKeys = AppKeys
  { tokenKey   :: ByteString
    -- ^ 미리보기 토큰 서명용('Blog.Publish').
  , sessionKey :: ByteString
    -- ^ 세션 쿠키 서명용('Blog.Auth').
  , verifyKey  :: ByteString
    -- ^ 가입 인증 코드 해시용('Blog.Verification' 흐름).
  }

-- | 마스터 비밀에서 라벨별 서브키를 파생한다.
--
-- @HMAC-SHA256(master, label)@ 의 16진수 표현(64자, 256비트)을 키 재료로 쓴다.
-- 라벨이 다르면 서브키가 완전히 갈라지므로 도메인 분리가 보장된다.
deriveKeys :: ByteString -> AppKeys
deriveKeys master = AppKeys (sub "preview-token") (sub "session-cookie") (sub "email-verify")
  where
    sub :: ByteString -> ByteString
    sub label = BS8.pack (show (hmacGetDigest (hmac master label :: HMAC SHA256)))
