-- | [REQ-T001] 테스트 진입점
module Main
  where

import Test.Hspec

import Integration.ApiHandlerSpec qualified
import Integration.CommentServiceSpec qualified
import Integration.PostServiceSpec qualified
import TestFoundation ()
import Unit.ApiCommentHelperSpec qualified
import Unit.ApiPostHelperSpec qualified
import Unit.AuthServiceSpec qualified

main :: IO ()
main = hspec $ do
  Unit.AuthServiceSpec.spec
  Unit.ApiPostHelperSpec.spec
  Unit.ApiCommentHelperSpec.spec
  Integration.PostServiceSpec.spec
  Integration.CommentServiceSpec.spec
  Integration.ApiHandlerSpec.spec
