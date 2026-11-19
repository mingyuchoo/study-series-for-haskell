{-# LANGUAGE OverloadedStrings #-}

import Test.Hspec

import ConfigSpec qualified
import DBSpec qualified
import I18nSpec qualified
import RepositorySpec qualified
import TodoStatusSpec qualified
import UI.AttributesSpec qualified
import UI.DrawSpec qualified
import UI.EventsSpec qualified
import UI.TypesSpec qualified

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
  describe "Repository" RepositorySpec.spec
  describe "Config" ConfigSpec.spec
  describe "DB" DBSpec.spec
  describe "I18n" I18nSpec.spec
  describe "TodoStatus" TodoStatusSpec.spec
  describe "UI.Types" UI.TypesSpec.spec
  describe "UI.Events" UI.EventsSpec.spec
  describe "UI.Draw" UI.DrawSpec.spec
  describe "UI.Attributes" UI.AttributesSpec.spec
