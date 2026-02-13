{-# LANGUAGE OverloadedStrings #-}

import           Test.Hspec

import qualified AppSpec
import qualified ConfigSpec
import qualified DBSpec
import qualified I18nSpec
import qualified TodoServiceSpec
import qualified TodoStatusSpec
import qualified UI.AttributesSpec
import qualified UI.DrawSpec
import qualified UI.EventsSpec
import qualified UI.TypesSpec

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
  describe "App" AppSpec.spec
  describe "Config" ConfigSpec.spec
  describe "DB" DBSpec.spec
  describe "I18n" I18nSpec.spec
  describe "TodoStatus" TodoStatusSpec.spec
  describe "TodoService" TodoServiceSpec.spec
  describe "UI.Types" UI.TypesSpec.spec
  describe "UI.Events" UI.EventsSpec.spec
  describe "UI.Draw" UI.DrawSpec.spec
  describe "UI.Attributes" UI.AttributesSpec.spec
