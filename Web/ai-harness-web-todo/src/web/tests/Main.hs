module Main (main) where

import Test.Hspec (hspec)
import qualified Todo.Web.ConfigSpec
import qualified Todo.Web.FormSpec
import qualified Todo.Web.RouteSpec
import qualified Todo.Web.SecuritySpec
import qualified Todo.Web.ViewSpec

main :: IO ()
main = hspec $ do
  Todo.Web.ConfigSpec.spec
  Todo.Web.RouteSpec.spec
  Todo.Web.FormSpec.spec
  Todo.Web.SecuritySpec.spec
  Todo.Web.ViewSpec.spec
