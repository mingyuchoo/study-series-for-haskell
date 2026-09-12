-- | 테스트 러너 — 라우트·Org·보안 스펙을 모아 실행한다.
module Main
  ( main
  ) where

import System.IO (hSetEncoding, stderr, stdout, utf8)
import Test.HUnit (Test (..), runTestTTAndExit)

import DerivingSpec (derivingTests)
import DomainSpec (domainTests)
import OrgSpec (orgTests)
import RouteSpec (routeTests)
import SecuritySpec (securityTests)

main :: IO ()
main = do
  -- 컨테이너/CI 환경의 로케일이 C(ASCII)여도 한글 로그를 정상 출력할 수 있도록 UTF-8 강제.
  hSetEncoding stdout utf8
  hSetEncoding stderr utf8
  runTestTTAndExit $
    TestList [routeTests, orgTests, securityTests, domainTests, derivingTests]
