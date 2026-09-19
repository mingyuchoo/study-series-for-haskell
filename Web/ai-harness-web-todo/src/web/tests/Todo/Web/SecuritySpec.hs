{-# LANGUAGE OverloadedStrings #-}

-- | 변경 요청의 출처 확인 검증입니다.
--
-- 이 표면에는 세션이 없어 SameSite 쿠키 방어가 적용되지 않습니다. 폼 제출은 CORS의
-- 제약도 받지 않으므로, 확인이 없으면 사용자가 방문한 임의의 페이지가 루프백 주소로
-- 변경 요청을 보낼 수 있습니다.
module Todo.Web.SecuritySpec (spec) where

import qualified Data.Text as Text
import Test.Hspec
import Todo.Web.Security

spec :: Spec
spec = do
  describe "Sec-Fetch-Site 확인" $ do
    it "같은 출처의 요청만 받아들인다" $
      checkFetchSite (Just "same-origin") `shouldBe` Right ()

    it "다른 사이트의 요청을 거부한다" $
      checkFetchSite (Just "cross-site") `shouldBe` Left (FetchSiteForeign "cross-site")

    it "같은 사이트라도 같은 출처가 아니면 거부한다" $
      -- same-site는 다른 하위 도메인을 포함합니다. 루프백 전용 표면에서 넓힐 이유가
      -- 없습니다.
      checkFetchSite (Just "same-site") `shouldBe` Left (FetchSiteForeign "same-site")

    it "사용자가 직접 연 요청도 변경에는 쓰지 않는다" $
      checkFetchSite (Just "none") `shouldBe` Left (FetchSiteForeign "none")

    it "헤더가 없으면 거부한다" $
      -- 헤더를 보내지 않는 클라이언트를 통과시키면 검사 자체가 무의미해집니다.
      checkFetchSite Nothing `shouldBe` Left FetchSiteMissing

    it "값을 대소문자까지 그대로 비교한다" $
      checkFetchSite (Just "Same-Origin") `shouldBe` Left (FetchSiteForeign "Same-Origin")

  describe "거부 안내" $ do
    it "받은 헤더 값을 화면에 되돌려 주지 않는다" $
      renderFetchSiteRejection (FetchSiteForeign "<script>evil</script>")
        `shouldNotSatisfy` Text.isInfixOf "script"

    it "헤더가 없을 때와 다른 출처일 때의 안내가 다르다" $
      renderFetchSiteRejection FetchSiteMissing
        `shouldNotBe` renderFetchSiteRejection (FetchSiteForeign "cross-site")
