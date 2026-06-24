-- | 테스트 러너 — 라우트·Org·보안 스펙을 모아 실행한다.
module Main
  ( main
  ) where

import Test.HUnit (Test (..), runTestTTAndExit)

import DerivingSpec (derivingTests)
import DomainSpec (domainTests)
import OrgSpec (orgTests)
import RouteSpec (routeTests)
import SecuritySpec (securityTests)

main :: IO ()
main =
  runTestTTAndExit $
    TestList [routeTests, orgTests, securityTests, domainTests, derivingTests]
