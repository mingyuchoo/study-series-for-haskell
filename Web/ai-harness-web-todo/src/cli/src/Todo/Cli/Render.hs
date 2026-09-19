{-# LANGUAGE OverloadedStrings #-}

-- | 출력 형식입니다.
--
-- 출력은 사람이 읽는 표면이면서 동시에 다른 도구가 파싱하는 대상이 될 수 있으므로
-- 형식 변경은 계약 변경으로 취급합니다. 순수 함수로 분리해 테스트할 수 있게 두었습니다.
module Todo.Cli.Render (
  renderTodoLine,
  renderTodoList,
  renderUseCaseError,
) where

import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as T
import Todo.Core.Status (TransitionError (..))
import Todo.Core.Types (
  Priority (..),
  Tag (..),
  Title (..),
  Todo (..),
  TodoId (..),
  statusName,
 )
import Todo.Core.UseCase (UseCaseError (..))

-- | 할 일 하나를 한 줄로 표현합니다.
--
-- 형식: @<id>  <상태>  <우선순위 표시> <제목> [태그] (마감 <날짜>)@
renderTodoLine :: Todo -> Text
renderTodoLine todo =
  T.intercalate
    "  "
    ( filter
        (not . T.null)
        [ T.justifyRight 4 ' ' (T.pack (show (unTodoId (todoId todo))))
        , T.justifyLeft 11 ' ' (statusName (todoStatus todo))
        , priorityMark (todoPriority todo) <> unTitle (todoTitle todo)
        , renderTags (todoTags todo)
        , renderDue todo
        ]
    )

-- | 우선순위를 짧은 접두 기호로 표현합니다.
priorityMark :: Priority -> Text
priorityMark p = case p of
  Low -> ""
  Normal -> ""
  High -> "! "
  Urgent -> "!! "

renderTags :: Set Tag -> Text
renderTags tags
  | Set.null tags = ""
  | otherwise = "[" <> T.intercalate " " [unTag t | t <- Set.toAscList tags] <> "]"

renderDue :: Todo -> Text
renderDue todo = case todoDueOn todo of
  Nothing -> ""
  Just day -> "(마감 " <> T.pack (show day) <> ")"

-- | 목록 전체를 표현합니다. 비어 있으면 안내 문구를 돌려줍니다.
renderTodoList :: [Todo] -> Text
renderTodoList [] = "조건에 맞는 할 일이 없습니다."
renderTodoList todos = T.intercalate "\n" (map renderTodoLine todos)

-- | 유스케이스 오류를 사용자 메시지로 바꿉니다.
renderUseCaseError :: UseCaseError -> Text
renderUseCaseError err = case err of
  TodoNotFound (TodoId tid) ->
    "할 일을 찾을 수 없습니다: " <> T.pack (show tid)
  InvalidTransition (TodoId tid) (SameStatus status) ->
    "할 일 " <> T.pack (show tid) <> "은(는) 이미 " <> statusName status <> " 상태입니다."
  InvalidTransition (TodoId tid) (ForbiddenTransition from to) ->
    "할 일 "
      <> T.pack (show tid)
      <> "을(를) "
      <> statusName from
      <> "에서 "
      <> statusName to
      <> "(으)로 바꿀 수 없습니다."
