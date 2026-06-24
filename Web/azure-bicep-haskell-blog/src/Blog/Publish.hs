{-# LANGUAGE DataKinds      #-}
{-# LANGUAGE KindSignatures #-}

-- | 발행 흐름을 타입으로 강제하는 글 모델.
--
-- 글은 두 단계를 가진다: 'Draft'(초안) → 'Previewed'(미리보기 검증됨).
-- 'Article' 값 생성자는 모듈 밖으로 노출하지 않으므로, @Article 'Previewed@
-- 값은 오직 'verifyPreviewed'(서명 토큰 검증)를 통해서만 만들 수 있다.
--
-- 따라서 발행 함수의 인자를 @Article 'Previewed@ 로 두면, 미리보기를 거치지
-- 않은 발행은 __컴파일 타임에 불가능__해진다. 토큰은 비밀키 HMAC 서명이라
-- 위조할 수 없고 내용이 바뀌면 검증에 실패하므로, __런타임__에서도 미리보기를
-- 건너뛴 직접 POST 발행이 차단된다.
module Blog.Publish
  ( Stage (..)
  , Article
  , articleTitle
  , articleBody
  , mkDraft
  , PostTarget (..)
  , Token (..)
  , signDraft
  , verifyPreviewed
  ) where

import Crypto.Hash.Algorithms (SHA256)
import Crypto.MAC.HMAC (HMAC, hmac, hmacGetDigest)
import Data.ByteString (ByteString)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Encoding (encodeUtf8)

-- | 글의 발행 단계. 타입 인덱스(phantom)로만 쓰인다 — 값은 만들지 않는다.
data Stage = Draft | Previewed

-- | 발행 단계를 타입으로 갖는 글.
--
-- 값 생성자('Article')는 export 하지 않는다. 그래야 @Article 'Previewed@ 를
-- 임의로 만들 수 없고, 오직 'verifyPreviewed' 만이 그 값을 생산한다.
data Article (s :: Stage) = Article
  { articleTitle :: Text
  , articleBody  :: Text
  }
  deriving stock (Eq, Show)

-- | 사용자 입력으로 초안을 만든다.
mkDraft :: Text -> Text -> Article 'Draft
mkDraft = Article

-- | 미리보기/발행의 대상. 토큰이 이 대상에 묶이므로, 새 글용 토큰을 기존 글
--   수정에 재사용하거나 다른 글 id로 바꿔치기할 수 없다.
data PostTarget -- | 새 글 작성(insert)
                = NewTarget
                -- | 기존 글 수정(update). 대상 글 id.
                | EditTarget Int
  deriving stock (Eq, Show)

-- | 서명 메시지에 섞는 대상 태그.
targetTag :: PostTarget -> Text
targetTag NewTarget        = "new"
targetTag (EditTarget pid) = "edit:" <> T.pack (show pid)

-- | 미리보기 토큰. 초안 내용에 대한 서버 서명(HMAC-SHA256, 16진수 문자열).
newtype Token = Token { unToken :: Text }
  deriving stock (Eq, Show)

-- | 비밀키로 (대상 + 초안 내용)을 서명해 토큰을 발급한다(미리보기 단계).
signDraft :: ByteString -> PostTarget -> Article 'Draft -> Token
signDraft key target (Article title body) =
  Token (T.pack (show (hmacGetDigest mac)))
  where
    -- 대상/제목/본문 경계를 NUL로 구분해 인접 필드의 결합 모호성을 없앤다.
    mac :: HMAC SHA256
    mac = hmac key (encodeUtf8 (targetTag target <> "\NUL" <> title <> "\NUL" <> body))

-- | 토큰이 (대상 + 내용)과 일치할 때만 @Article 'Previewed@ 를 만든다(발행 단계).
--
-- 토큰은 서버 비밀키 서명이므로 위조할 수 없고, 미리보기 이후 내용이나 대상이
-- 바뀌면 서명이 달라져 'Nothing' 이 된다.
verifyPreviewed
  :: ByteString -> PostTarget -> Text -> Text -> Token -> Maybe (Article 'Previewed)
verifyPreviewed key target title body tok
  | signDraft key target (mkDraft title body) == tok = Just (Article title body)
  | otherwise = Nothing
