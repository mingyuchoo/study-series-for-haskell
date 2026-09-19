{-# LANGUAGE OverloadedStrings #-}

module Todo.Web.RouteSpec (spec) where

import qualified Data.Set as Set
import Test.Hspec
import Todo.Core.Filter (StatusFilter (..), TodoFilter (..))
import Todo.Core.Types (ListId (..), Status (..), Tag (..))
import Todo.Web.Route

spec :: Spec
spec = do
  describe "경로 해석" $ do
    it "빈 경로는 목록 화면이다" $
      parseRoute "GET" [] [] `shouldBe` Right (ListRoute emptyListQuery)

    it "/todos도 목록 화면이다" $
      parseRoute "GET" ["todos"] [] `shouldBe` Right (ListRoute emptyListQuery)

    it "/todos/3은 상세 화면이다" $
      parseRoute "GET" ["todos", "3"] [] `shouldBe` Right (DetailRoute 3)

    it "숫자가 아닌 식별자는 상세 화면이 아니다" $
      parseRoute "GET" ["todos", "abc"] [] `shouldBe` Right UnknownRoute

    it "음수 식별자를 받지 않는다" $
      parseRoute "GET" ["todos", "-1"] [] `shouldBe` Right UnknownRoute

    it "알 수 없는 경로는 UnknownRoute이다" $
      parseRoute "GET" ["admin"] [] `shouldBe` Right UnknownRoute

  describe "질의 해석" $ do
    it "status를 상태로 옮긴다" $
      fmap listQueryOf (parseRoute "GET" [] [("status", Just "done")])
        `shouldBe` Right (Just (emptyListQuery{queryStatus = Just Done}))

    it "알 수 없는 상태 이름을 거부한다" $
      parseRoute "GET" [] [("status", Just "finished")]
        `shouldBe` Left (UnknownStatusName "finished")

    it "빈 status는 지정하지 않은 것으로 본다" $
      fmap listQueryOf (parseRoute "GET" [] [("status", Just "")])
        `shouldBe` Right (Just emptyListQuery)

    it "태그를 여러 개 받는다" $
      fmap (fmap queryTags . listQueryOf) (parseRoute "GET" [] [("tag", Just "work"), ("tag", Just "home")])
        `shouldBe` Right (Just (Set.fromList [Tag "work", Tag "home"]))

    it "허용되지 않은 문자가 든 태그를 거부한다" $
      parseRoute "GET" [] [("tag", Just "work space")] `shouldSatisfy` isInvalidQueryValue

    it "list를 목록 식별자로 옮긴다" $
      fmap (fmap queryListId . listQueryOf) (parseRoute "GET" [] [("list", Just "home")])
        `shouldBe` Right (Just (Just (ListId "home")))

    it "값 없는 all을 켜진 것으로 본다" $
      fmap (fmap queryShowAll . listQueryOf) (parseRoute "GET" [] [("all", Nothing)])
        `shouldBe` Right (Just True)

    it "all=0은 꺼진 것으로 본다" $
      fmap (fmap queryShowAll . listQueryOf) (parseRoute "GET" [] [("all", Just "0")])
        `shouldBe` Right (Just False)

  describe "조회 조건 변환" $ do
    it "기본 조건은 끝나지 않은 할 일만 본다" $
      filterStatus (listFilter emptyListQuery) `shouldBe` ActiveOnly

    it "전체 보기는 상태를 제한하지 않는다" $
      filterStatus (listFilter emptyListQuery{queryShowAll = True}) `shouldBe` AnyStatus

    it "명시한 상태가 전체 보기보다 우선한다" $
      filterStatus (listFilter emptyListQuery{queryStatus = Just Done, queryShowAll = True})
        `shouldBe` ExactStatus Done

    it "태그와 목록 조건을 그대로 옮긴다" $
      let query =
            emptyListQuery
              { queryTags = Set.fromList [Tag "work"]
              , queryListId = Just (ListId "home")
              }
          f = listFilter query
       in (filterTags f, filterListId f)
            `shouldBe` (Set.fromList [Tag "work"], Just (ListId "home"))

  describe "오류 문구"
    $ it "내부 구조를 노출하지 않는다"
    $ renderRouteError (UnknownStatusName "finished")
      `shouldBe` "알 수 없는 상태입니다: finished"

  describe "변경 경로" $ do
    it "POST /todos는 생성이다" $
      parseRoute "POST" ["todos"] [] `shouldBe` Right CreateRoute

    it "POST /todos/1/edit은 수정이다" $
      parseRoute "POST" ["todos", "1", "edit"] [] `shouldBe` Right (EditRoute 1)

    it "POST /todos/1/status는 상태 변경이다" $
      parseRoute "POST" ["todos", "1", "status"] [] `shouldBe` Right (StatusRoute 1)

    it "GET /todos/1/delete는 확인 화면이지 삭제가 아니다" $
      parseRoute "GET" ["todos", "1", "delete"] [] `shouldBe` Right (DeleteFormRoute 1)

    it "POST /todos/1/delete가 실제 삭제이다" $
      parseRoute "POST" ["todos", "1", "delete"] [] `shouldBe` Right (DeleteRoute 1)

    it "GET으로 생성을 요청할 수 없다" $
      parseRoute "GET" ["todos"] [("title", Just "x")] `shouldNotBe` Right CreateRoute

    it "조회 경로에 POST를 보내면 메서드 불일치이다" $
      parseRoute "POST" ["todos", "1"] [] `shouldBe` Right MethodMismatch

    it "변경 경로에 GET을 보내면 메서드 불일치이다" $
      parseRoute "GET" ["todos", "1", "edit"] [] `shouldBe` Right MethodMismatch

    it "숫자가 아닌 식별자는 변경 경로가 되지 않는다" $
      parseRoute "POST" ["todos", "abc", "delete"] [] `shouldBe` Right UnknownRoute

  describe "쓰기 판정" $ do
    -- 이 목록이 출처 확인의 적용 범위를 정합니다. 새 변경 경로를 추가하면서
    -- isWriteRoute에 넣지 않으면 확인 없이 통과합니다.
    it "저장소를 바꾸는 경로만 쓰기로 본다" $
      filter isWriteRoute allRoutes
        `shouldBe` [CreateRoute, EditRoute 1, StatusRoute 1, DeleteRoute 1]

    it "삭제 확인 화면은 쓰기가 아니다" $
      isWriteRoute (DeleteFormRoute 1) `shouldBe` False

-- | 모든 생성자를 한 번씩 담습니다. 새 경로를 추가하면 여기에도 넣어야 하며,
-- 넣지 않으면 위 검증이 그 경로를 보지 못합니다.
allRoutes :: [Route]
allRoutes =
  [ ListRoute emptyListQuery
  , DetailRoute 1
  , DeleteFormRoute 1
  , CreateRoute
  , EditRoute 1
  , StatusRoute 1
  , DeleteRoute 1
  , MethodMismatch
  , UnknownRoute
  ]

listQueryOf :: Route -> Maybe ListQuery
listQueryOf route = case route of
  ListRoute query -> Just query
  _ -> Nothing

isInvalidQueryValue :: Either RouteError Route -> Bool
isInvalidQueryValue result = case result of
  Left (InvalidQueryValue _) -> True
  _ -> False
