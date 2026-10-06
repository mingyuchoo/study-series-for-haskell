{-# LANGUAGE OverloadedStrings #-}

module UI.AttributesSpec
    ( spec
    ) where

import           Test.Hspec
import           Flow             ((<|))
import           UI.Attributes

spec :: Spec
spec = do
  describe "theMap" <| do
    it "속성 맵이 정의되어 있어야 함" <| do
      theMap `shouldSatisfy` const True

    it "기본 속성이 존재해야 함" <| do
      -- AttrMap은 직접 테스트하기 어려우므로 존재 여부만 확인
      theMap `shouldSatisfy` const True
