{-# LANGUAGE OverloadedStrings #-}

module Todo.Web.ViewSpec (spec) where

import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Lazy as LazyText
import Data.Time (addDays)
import Lucid (Html, renderText)
import Test.Hspec
import Todo.Core.Filter (SortOrder (..), applyFilter, emptyFilter)
import Todo.Core.Status (allowedTransitions)
import Todo.Core.Types (Priority (..), Status (..), Tag (..), Title (..), Todo (..), TodoId (..), statusName)
import Todo.Web.Gen (fixedToday, sampleTodo)
import Todo.Web.Route (emptyListQuery, listFilter)
import Todo.Web.View

render :: Html () -> Text
render = LazyText.toStrict . renderText

renderPage :: Text -> Html () -> Text
renderPage title body = render (page title body)

spec :: Spec
spec = do
  describe "문서 껍데기" $ do
    it "사용자 입력을 이스케이프한다" $ do
      let output = renderPage "<script>alert(1)</script>" mempty
      output `shouldNotSatisfy` Text.isInfixOf "<script>alert(1)</script>"
      output `shouldSatisfy` Text.isInfixOf "&lt;script&gt;"

    it "외부 출처의 자산을 참조하지 않는다" $ do
      let output = renderPage "할 일" mempty
      output `shouldNotSatisfy` Text.isInfixOf "http://"
      output `shouldNotSatisfy` Text.isInfixOf "https://"
      output `shouldNotSatisfy` Text.isInfixOf "//cdn"

  describe "표시 문구" $ do
    it "모든 상태에 문구가 있다" $
      map statusLabel [minBound .. maxBound] `shouldBe` ["대기", "진행 중", "완료", "보관"]

    it "모든 우선순위에 문구가 있다" $
      map priorityLabel [minBound .. maxBound] `shouldBe` ["낮음", "보통", "높음", "긴급"]

    it "표시 문구는 계약에 실리는 값과 다른 층이다" $
      map statusName [minBound .. maxBound]
        `shouldBe` ["pending", "in_progress", "done", "archived"]

  describe "목록 화면" $ do
    it "새 할 일 폼을 담는다" $
      render (todoListSection mempty []) `shouldSatisfy` Text.isInfixOf "action=\"/todos\""
    it "할 일의 제목과 태그를 이스케이프한다" $ do
      let hostile =
            (sampleTodo 1)
              { todoTitle = Title "<img src=x onerror=alert(1)>"
              , todoTags = Set.fromList [Tag "work"]
              }
          output = render (todoListSection mempty [hostile])
      output `shouldNotSatisfy` Text.isInfixOf "<img src=x"
      output `shouldSatisfy` Text.isInfixOf "&lt;img"

    it "비어 있으면 오류가 아니라 안내 문구를 보여준다" $
      render (todoListSection mempty []) `shouldSatisfy` Text.isInfixOf "조건에 맞는 할 일이 없습니다."

    it "받은 순서를 바꾸지 않는다" $ do
      -- 정렬은 Todo.Core.Filter가 끝냈습니다. 뷰가 다시 정렬하면 표면마다 목록이
      -- 달라집니다(PROD-INV-003).
      let a = (sampleTodo 7){todoTitle = Title "첫째"}
          b = (sampleTodo 3){todoTitle = Title "둘째"}
          output = render (todoListSection mempty [a, b])
      indexOf "첫째" output `shouldSatisfy` (< indexOf "둘째" output)

    it "도메인이 정한 순서를 그대로 반영한다" $ do
      -- 마감일이 없는 할 일을 뒤로 보내는 것은 Todo.Core.Filter의 규칙입니다.
      let withDue = (sampleTodo 10){todoTitle = Title "마감있음", todoDueOn = Just (addDays 3 fixedToday)}
          withoutDue = (sampleTodo 11){todoTitle = Title "마감없음"}
          ordered = applyFilter emptyFilter ByDueDate [withoutDue, withDue]
          output = render (todoListSection mempty ordered)
      map todoId ordered `shouldBe` [TodoId 10, TodoId 11]
      indexOf "마감있음" output `shouldSatisfy` (< indexOf "마감없음" output)

    it "웹의 기본 조건은 끝나지 않은 할 일만 보여준다" $ do
      -- cli의 기본값과 같습니다. 두 표면 모두 resolveStatusFilter를 씁니다.
      let stillOpen = (sampleTodo 1){todoTitle = Title "남은일"}
          finished = (sampleTodo 2){todoTitle = Title "끝난일", todoStatus = Done}
          shown = applyFilter (listFilter emptyListQuery) ByDueDate [stillOpen, finished]
      map todoId shown `shouldBe` [TodoId 1]

  describe "조건 막대" $ do
    it "주소에는 표시 문구가 아니라 상태 이름을 싣는다" $ do
      let output = render (filterBar Nothing False)
      output `shouldSatisfy` Text.isInfixOf "/?status=in_progress"
      output `shouldNotSatisfy` Text.isInfixOf "/?status=진행 중"

    it "현재 조건은 링크가 아니라 강조로 표시한다" $
      render (filterBar (Just Done) False)
        `shouldSatisfy` Text.isInfixOf "<span class=\"current\">완료</span>"

  describe "상세 화면" $ do
    it "제목을 이스케이프한다" $ do
      let hostile = (sampleTodo 1){todoTitle = Title "<b>굵게</b>"}
          output = render (todoDetailSection [] hostile)
      output `shouldNotSatisfy` Text.isInfixOf "<b>굵게</b>"
      output `shouldSatisfy` Text.isInfixOf "&lt;b&gt;"

    it "허용된 전이만 단추로 보여준다" $ do
      -- 어떤 전이가 가능한지는 Todo.Core.Status가 답합니다. 뷰는 받은 목록만 그립니다.
      let todo = sampleTodo 1
          output = render (todoDetailSection (allowedTransitions (todoStatus todo)) todo)
      output `shouldSatisfy` Text.isInfixOf "value=\"done\""
      output `shouldNotSatisfy` Text.isInfixOf "value=\"pending\""

    it "종료 상태에는 상태 변경 단추가 없다" $ do
      let archived = (sampleTodo 1){todoStatus = Archived}
          output = render (todoDetailSection (allowedTransitions Archived) archived)
      allowedTransitions Archived `shouldBe` []
      output `shouldNotSatisfy` Text.isInfixOf "상태 바꾸기"

    it "삭제는 확인 화면을 거치는 링크이다" $ do
      -- 삭제를 폼 단추로 바로 두면 실수 한 번으로 되돌릴 수 없습니다(PROD-INV-001).
      let output = render (todoDetailSection [] (sampleTodo 1))
      output `shouldSatisfy` Text.isInfixOf "href=\"/todos/1/delete\""
      output `shouldNotSatisfy` Text.isInfixOf "action=\"/todos/1/delete\""

    it "폼의 값은 표시 문구가 아니라 저장 값이다" $ do
      let todo = (sampleTodo 1){todoPriority = High}
          output = render (todoDetailSection [] todo)
      output `shouldSatisfy` Text.isInfixOf "selected=\"selected\" value=\"high\""
      output `shouldNotSatisfy` Text.isInfixOf "value=\"높음\""

  describe "삭제 확인 화면" $ do
    it "삭제를 실행하는 폼을 담는다" $
      render (deleteConfirmSection (sampleTodo 1))
        `shouldSatisfy` Text.isInfixOf "action=\"/todos/1/delete\""

    it "되돌릴 수 없다는 것과 보관이라는 대안을 함께 알린다" $ do
      let output = render (deleteConfirmSection (sampleTodo 1))
      output `shouldSatisfy` Text.isInfixOf "되돌릴 수 없습니다"
      output `shouldSatisfy` Text.isInfixOf "보관"

    it "제목을 이스케이프한다" $
      render (deleteConfirmSection ((sampleTodo 1){todoTitle = Title "<b>x</b>"}))
        `shouldSatisfy` Text.isInfixOf "&lt;b&gt;"

  describe "안내 화면"
    $ it "전달받은 문구를 이스케이프한다"
    $ render (messageSection "<i>없음</i>") `shouldSatisfy` Text.isInfixOf "&lt;i&gt;"

-- | 출력에서 문구가 나타나는 위치입니다. 없으면 실패하도록 큰 값을 돌려줍니다.
indexOf :: Text -> Text -> Int
indexOf needle haystack =
  let (front, rest) = Text.breakOn needle haystack
   in if Text.null rest then maxBound else Text.length front
