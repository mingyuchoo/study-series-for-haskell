{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedStrings #-}

-- | 상태를 바꾸는 요청의 출처 확인입니다.
--
-- 이 표면에는 세션이 없습니다. 쿠키가 없으므로 브라우저의 @SameSite@ 방어가 적용되지
-- 않고, CSRF 토큰은 서버가 상태를 들고 있어야 하므로 쓰지 않습니다.
--
-- 대신 @Sec-Fetch-Site@를 확인합니다. 이 헤더는 브라우저가 붙이며 페이지 스크립트가
-- 위조할 수 없습니다. 상태를 남기지 않는다는 점도 이 제품에 맞습니다.
--
-- 폼 제출은 CORS의 제약을 받지 않는다는 점이 이 검사가 필요한 이유입니다. 사용자가
-- 방문한 임의의 페이지가 루프백 주소로 폼을 보낼 수 있고, 인증이 없으므로 그 요청은
-- 그대로 성공합니다. 근거는 @docs/decisions/ADR-0004-web-surface.md@에 있습니다.
module Todo.Web.Security (
  FetchSiteRejection (..),
  checkFetchSite,
  renderFetchSiteRejection,
) where

import Data.Text (Text)

-- | 출처 확인이 거부된 이유입니다.
data FetchSiteRejection
  = -- | 헤더가 없습니다. 이 헤더를 보내지 않는 클라이언트도 거부합니다.
    FetchSiteMissing
  | -- | 같은 출처가 아닙니다. 값을 그대로 보관해 안내에 쓰지는 않습니다.
    FetchSiteForeign Text
  deriving stock (Eq, Show)

-- | 상태를 바꾸는 요청을 받아들일지 판단합니다.
--
-- @same-origin@만 허용합니다. @same-site@를 함께 허용하지 않는 이유는 그것이 다른
-- 하위 도메인을 포함하기 때문이며, 루프백 전용 표면에서는 넓힐 이유가 없습니다.
--
-- 헤더가 없는 요청도 거부합니다. 이 헤더를 보내지 않는 오래된 브라우저에서 변경
-- 기능이 동작하지 않지만, 그 경우에도 조회는 되고 @cli@와 @api@가 그대로
-- 있습니다. 확인할 수 없는 출처를 허용하는 것보다 낫습니다.
checkFetchSite :: Maybe Text -> Either FetchSiteRejection ()
checkFetchSite header = case header of
  Nothing -> Left FetchSiteMissing
  Just "same-origin" -> Right ()
  Just other -> Left (FetchSiteForeign other)

-- | 거부 사유를 사용자 문구로 바꿉니다.
--
-- 받은 헤더 값을 그대로 화면에 싣지 않습니다. 값은 요청자가 정하는 문자열이며 화면에
-- 되돌려 줄 이유가 없습니다.
renderFetchSiteRejection :: FetchSiteRejection -> Text
renderFetchSiteRejection rejection = case rejection of
  FetchSiteMissing ->
    "이 브라우저에서는 변경 요청을 확인할 수 없어 처리하지 않았습니다."
  FetchSiteForeign _ ->
    "다른 사이트에서 온 변경 요청이므로 처리하지 않았습니다."
