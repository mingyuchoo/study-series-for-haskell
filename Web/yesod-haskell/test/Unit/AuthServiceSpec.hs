{-# LANGUAGE OverloadedStrings #-}

-- | [REQ-T001, REQ-F002] AuthService 단위 테스트
--
-- 이 테스트는 다음 요구사항을 검증합니다:
--   - REQ-F002: 사용자 인증 (회원가입/로그인) - 비밀번호 해시 및 검증 로직
module Unit.AuthServiceSpec (spec) where

import Test.Hspec
import Service.AuthService (hashPassword, verifyPassword)

spec :: Spec
spec = describe "Service.AuthService" $ do

    describe "hashPassword" $ do
        it "비밀번호를 해시하면 Just를 반환한다" $ do
            mHash <- hashPassword "testpassword123"
            mHash `shouldSatisfy` (/= Nothing)

        it "해시된 비밀번호를 verifyPassword로 검증할 수 있다" $ do
            mHash <- hashPassword "mySecurePass"
            case mHash of
                Nothing -> expectationFailure "해시 생성 실패"
                Just hash -> verifyPassword "mySecurePass" hash `shouldBe` True

    describe "verifyPassword" $ do
        it "올바른 비밀번호는 True를 반환한다" $ do
            mHash <- hashPassword "correctPassword"
            case mHash of
                Nothing -> expectationFailure "해시 생성 실패"
                Just hash -> verifyPassword "correctPassword" hash `shouldBe` True

        it "틀린 비밀번호는 False를 반환한다" $ do
            mHash <- hashPassword "correctPassword"
            case mHash of
                Nothing -> expectationFailure "해시 생성 실패"
                Just hash -> verifyPassword "wrongPassword" hash `shouldBe` False

        it "빈 문자열 비밀번호도 처리할 수 있다" $ do
            mHash <- hashPassword ""
            case mHash of
                Nothing -> expectationFailure "해시 생성 실패"
                Just hash -> do
                    verifyPassword "" hash `shouldBe` True
                    verifyPassword "notempty" hash `shouldBe` False
