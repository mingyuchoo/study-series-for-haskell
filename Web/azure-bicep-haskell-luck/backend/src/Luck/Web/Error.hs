{-# LANGUAGE LambdaCase #-}

-- | 웹 경계 어댑터: 도메인 'DomainError' 를 Servant 'ServerError' 로 변환한다.
--   도메인/핸들러는 HTTP 상태코드를 몰라도 되며, 매핑은 여기 한곳에 모인다.
module Luck.Web.Error
    ( jsonErr
    , toServerError
    ) where

import           Data.Aeson (encode)
import           Data.Text  (Text)
import           Luck.Error (DomainError (..))
import           Luck.Types (MessageResp (..))
import           Servant

-- | 도메인 에러 → HTTP 응답.
toServerError :: DomainError -> ServerError
toServerError = \case
  ValidationError m -> jsonErr err400 m
  EmailTaken -> jsonErr err409 "이미 가입된 이메일입니다."
  InvalidCredentials -> jsonErr err401 "이메일 또는 비밀번호가 올바르지 않습니다."
  Forbidden m -> jsonErr err403 m
  Conflict m -> jsonErr err409 m
  NotFound m -> jsonErr err404 m
  TokenFailure -> jsonErr err500 "토큰 발급에 실패했습니다."
  InternalError m -> jsonErr err500 m

-- | 에러 응답을 JSON 메시지 형태로 만든다.
jsonErr :: ServerError -> Text -> ServerError
jsonErr e msg =
  e
    { errBody = encode (MessageResp msg)
    , errHeaders = [("Content-Type", "application/json;charset=utf-8")]
    }
