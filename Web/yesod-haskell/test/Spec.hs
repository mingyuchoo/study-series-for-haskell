-- | [REQ-T001] 테스트 진입점
module Main where

import Test.Hspec

import TestFoundation ()
import qualified Unit.AuthServiceSpec
import qualified Unit.ApiPostHelperSpec
import qualified Unit.ApiCommentHelperSpec
import qualified Integration.PostServiceSpec
import qualified Integration.CommentServiceSpec
import qualified Integration.ApiHandlerSpec

main :: IO ()
main = hspec $ do
    Unit.AuthServiceSpec.spec
    Unit.ApiPostHelperSpec.spec
    Unit.ApiCommentHelperSpec.spec
    Integration.PostServiceSpec.spec
    Integration.CommentServiceSpec.spec
    Integration.ApiHandlerSpec.spec
