{-# LANGUAGE OverloadedStrings #-}

module TodoStatusSpec
    ( spec
    ) where

import           TodoStatus

import           Flow      ((<|))
import           Test.Hspec

spec :: Spec
spec = do
  describe "registered" <| do
    it "Registered 상태를 생성해야 함" <| do
      show registered `shouldBe` "Registered"

  describe "startProgress" <| do
    it "Registered에서 InProgress로 전환해야 함" <| do
      show (startProgress registered) `shouldBe` "InProgress"

  describe "cancel" <| do
    it "InProgress에서 Cancelled로 전환해야 함" <| do
      show (cancel StatusInProgress) `shouldBe` "Cancelled"

  describe "complete" <| do
    it "Cancelled에서 Completed로 전환해야 함" <| do
      show (complete StatusCancelled) `shouldBe` "Completed"

  describe "resetToRegistered" <| do
    it "Completed에서 Registered로 전환해야 함" <| do
      show (resetToRegistered StatusCompleted) `shouldBe` "Registered"

  describe "전체 상태 순환" <| do
    it "Registered → InProgress → Cancelled → Completed → Registered 순환이 되어야 함" <| do
      let s1 = registered
          s2 = startProgress s1
          s3 = cancel s2
          s4 = complete s3
          s5 = resetToRegistered s4
      show s1 `shouldBe` "Registered"
      show s2 `shouldBe` "InProgress"
      show s3 `shouldBe` "Cancelled"
      show s4 `shouldBe` "Completed"
      show s5 `shouldBe` "Registered"

  describe "statusToString" <| do
    it "Registered를 'registered'로 변환해야 함" <| do
      statusToString StatusRegistered `shouldBe` "registered"

    it "InProgress를 'in_progress'로 변환해야 함" <| do
      statusToString StatusInProgress `shouldBe` "in_progress"

    it "Cancelled를 'cancelled'로 변환해야 함" <| do
      statusToString StatusCancelled `shouldBe` "cancelled"

    it "Completed를 'completed'로 변환해야 함" <| do
      statusToString StatusCompleted `shouldBe` "completed"

  describe "stringToStatus" <| do
    it "'registered' 문자열을 파싱해야 함" <| do
      fmap show (stringToStatus "registered") `shouldBe` Just "Registered"

    it "'in_progress' 문자열을 파싱해야 함" <| do
      fmap show (stringToStatus "in_progress") `shouldBe` Just "InProgress"

    it "'cancelled' 문자열을 파싱해야 함" <| do
      fmap show (stringToStatus "cancelled") `shouldBe` Just "Cancelled"

    it "'completed' 문자열을 파싱해야 함" <| do
      fmap show (stringToStatus "completed") `shouldBe` Just "Completed"

    it "알 수 없는 문자열은 Nothing을 반환해야 함" <| do
      fmap show (stringToStatus "unknown") `shouldBe` Nothing

    it "빈 문자열은 Nothing을 반환해야 함" <| do
      fmap show (stringToStatus "") `shouldBe` Nothing

  describe "상태 확인 함수" <| do
    it "isRegistered가 Registered 상태를 식별해야 함" <| do
      case stringToStatus "registered" of
        Just s  -> isRegistered s `shouldBe` True
        Nothing -> expectationFailure "파싱 실패"

    it "isInProgress가 InProgress 상태를 식별해야 함" <| do
      case stringToStatus "in_progress" of
        Just s  -> isInProgress s `shouldBe` True
        Nothing -> expectationFailure "파싱 실패"

    it "isCancelled가 Cancelled 상태를 식별해야 함" <| do
      case stringToStatus "cancelled" of
        Just s  -> isCancelled s `shouldBe` True
        Nothing -> expectationFailure "파싱 실패"

    it "isCompleted가 Completed 상태를 식별해야 함" <| do
      case stringToStatus "completed" of
        Just s  -> isCompleted s `shouldBe` True
        Nothing -> expectationFailure "파싱 실패"

    it "isCompleted가 다른 상태에 False를 반환해야 함" <| do
      case stringToStatus "registered" of
        Just s  -> isCompleted s `shouldBe` False
        Nothing -> expectationFailure "파싱 실패"

  describe "상태 전환 일관성" <| do
    it "statusToString과 stringToStatus가 역함수 관계여야 함" <| do
      fmap show (stringToStatus (statusToString StatusRegistered)) `shouldBe` Just "Registered"
      fmap show (stringToStatus (statusToString StatusInProgress)) `shouldBe` Just "InProgress"
      fmap show (stringToStatus (statusToString StatusCancelled)) `shouldBe` Just "Cancelled"
      fmap show (stringToStatus (statusToString StatusCompleted)) `shouldBe` Just "Completed"
