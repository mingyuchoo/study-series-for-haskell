{-# LANGUAGE OverloadedStrings #-}

-- | HTML 표현입니다.
--
-- 이 모듈이 브라우저 표면의 전송 표현을 소유합니다. 도메인 타입에 렌더링 인스턴스를
-- 붙이지 않는 것은 @Todo.Api.Types@가 JSON에 대해 따르는 원칙과 같습니다
-- (@docs/decisions/ADR-0003-api-boundary.md@).
--
-- 이 모듈은 규칙을 판단하지 않습니다. 목록의 내용과 순서는 "Todo.Core.Filter"가
-- 정한 결과를 그대로 받아 표시하고, 여기서 다시 거르거나 정렬하지 않습니다.
module Todo.Web.View (
  page,
  statusLabel,
  priorityLabel,
  filterBar,
  todoListSection,
  todoDetailSection,
  deleteConfirmSection,
  messageSection,
) where

import Data.Maybe (isNothing)
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as T
import Lucid
import Todo.Core.Types (
  ListId (..),
  Priority (..),
  Status (..),
  Tag (..),
  Title (..),
  Todo (..),
  TodoId (..),
  priorityName,
  statusName,
 )

-- | 모든 화면이 공유하는 문서 껍데기입니다.
--
-- 외부 출처의 자산을 참조하지 않습니다. 원격 의존이 없다는 것이 이 제품의 전제이며
-- (@docs/product/invariants.md@의 @PROD-INV-005@), 스타일시트도 예외가 아닙니다.
page :: Text -> Html () -> Html ()
page title body_' = doctypehtml_ $ do
  head_ $ do
    meta_ [charset_ "utf-8"]
    meta_ [name_ "viewport", content_ "width=device-width, initial-scale=1"]
    title_ (toHtml title)
    style_ styleSheet
  body_ $ do
    header_ $ do
      h1_ (a_ [href_ "/"] (toHtml title))
    main_ body_'

-- | 상태를 사람이 읽는 문구로 옮깁니다.
--
-- 화면에 보이는 말과 계약에 실리는 값은 다른 층입니다. 저장되거나 질의 문자열에
-- 실리는 값은 "Todo.Core.Types"의 @statusName@이며 이 함수가 아닙니다
-- (@docs/product/terminology.md@).
statusLabel :: Status -> Text
statusLabel status = case status of
  Pending -> "대기"
  InProgress -> "진행 중"
  Done -> "완료"
  Archived -> "보관"

-- | 우선순위를 사람이 읽는 문구로 옮깁니다. 위와 같은 이유로 저장 값과 분리합니다.
priorityLabel :: Priority -> Text
priorityLabel priority = case priority of
  Low -> "낮음"
  Normal -> "보통"
  High -> "높음"
  Urgent -> "긴급"

-- | 상태 조건을 고르는 막대입니다.
--
-- 링크의 질의 값은 표시 문구가 아니라 @statusName@입니다. 화면에 보이는 말과
-- 주소에 실리는 값은 다른 층입니다.
--
-- 어떤 항목을 굵게 표시할지는 지금 요청이 무엇이었는지만 보고 정합니다. 목록의
-- 내용을 여기서 다시 판단하지 않습니다.
filterBar :: Maybe Status -> Bool -> Html ()
filterBar selected showAll = nav_ [class_ "filters"] $ do
  choice "남은 일" (isNothing selected && not showAll) "/"
  choice "전체" (isNothing selected && showAll) "/?all"
  mapM_ statusChoice [minBound .. maxBound]
 where
  statusChoice status =
    choice
      (statusLabel status)
      (selected == Just status)
      ("/?status=" <> statusName status)

  -- lucid의 태그 함수는 다형이므로 지역 보조 함수에 타입을 명시합니다.
  choice :: Text -> Bool -> Text -> Html ()
  choice label isCurrent href
    | isCurrent = span_ [class_ "current"] (toHtml label)
    | otherwise = a_ [href_ href] (toHtml label)

-- | 새 할 일을 만드는 폼입니다.
--
-- 값 검증은 서버가 합니다. @required@ 같은 브라우저 속성은 편의를 위한 것이고
-- 규칙이 아닙니다. 규칙은 "Todo.Core.Validation" 한 곳에만 있습니다.
createForm :: Html ()
createForm = form_ [method_ "post", action_ "/todos", class_ "create"] $ do
  input_ [type_ "text", name_ "title", placeholder_ "할 일", required_ "required"]
  input_ [type_ "text", name_ "tags", placeholder_ "태그 (공백으로 구분)"]
  input_ [type_ "date", name_ "due"]
  prioritySelect Normal
  button_ [type_ "submit"] "추가"

-- | 우선순위 고르기입니다. 값은 표시 문구가 아니라 @priorityName@입니다.
prioritySelect :: Priority -> Html ()
prioritySelect selected = select_ [name_ "priority"] (mapM_ option [minBound .. maxBound])
 where
  option :: Priority -> Html ()
  option priority =
    let attributes = [value_ (priorityName priority)]
        chosen = if priority == selected then (selected_ "selected" :) else id
     in option_ (chosen attributes) (toHtml (priorityLabel priority))

-- | 목록 화면의 본문입니다.
--
-- 받은 순서를 그대로 출력합니다. 정렬은 "Todo.Core.Filter"가 이미 끝냈습니다.
todoListSection :: Html () -> [Todo] -> Html ()
todoListSection bar todos = do
  createForm
  bar
  if null todos
    then p_ [class_ "empty"] "조건에 맞는 할 일이 없습니다."
    else table_ $ do
      thead_ $
        tr_ $ do
          th_ "번호"
          th_ "상태"
          th_ "제목"
          th_ "우선순위"
          th_ "태그"
          th_ "마감"
      tbody_ (mapM_ todoRow todos)

todoRow :: Todo -> Html ()
todoRow todo = tr_ $ do
  td_ (toHtml (todoIdText todo))
  td_ (toHtml (statusLabel (todoStatus todo)))
  td_ (a_ [href_ (detailPath todo)] (toHtml (unTitle (todoTitle todo))))
  td_ (toHtml (priorityLabel (todoPriority todo)))
  td_ (toHtml (tagsText (todoTags todo)))
  td_ (toHtml (dueText todo))

-- | 상세 화면의 본문입니다.
--
-- 상태 변경 단추는 'allowed'가 넘겨준 목록만 보여줍니다. 어떤 전이가 가능한지는
-- "Todo.Core.Status"가 답하며 이 모듈은 판단하지 않습니다.
todoDetailSection :: [Status] -> Todo -> Html ()
todoDetailSection allowed todo = do
  h2_ (toHtml (unTitle (todoTitle todo)))
  dl_ $ do
    field "번호" (todoIdText todo)
    field "상태" (statusLabel (todoStatus todo))
    field "우선순위" (priorityLabel (todoPriority todo))
    field "목록" (listText todo)
    field "태그" (tagsText (todoTags todo))
    field "마감" (dueText todo)
  statusForms allowed todo
  editForm todo
  p_ [class_ "actions"] $ do
    a_ [href_ "/"] "목록으로"
    a_ [href_ (detailPath todo <> "/delete"), class_ "danger"] "삭제"
 where
  field :: Text -> Text -> Html ()
  field name value = do
    dt_ (toHtml name)
    dd_ (toHtml value)

-- | 허용된 전이마다 단추를 하나씩 만듭니다. 비어 있으면 아무것도 그리지 않습니다.
statusForms :: [Status] -> Todo -> Html ()
statusForms allowed todo
  | null allowed = mempty
  | otherwise = section_ [class_ "transitions"] $ do
      h3_ "상태 바꾸기"
      mapM_ statusButton allowed
 where
  statusButton :: Status -> Html ()
  statusButton status =
    form_ [method_ "post", action_ (detailPath todo <> "/status")] $ do
      input_ [type_ "hidden", name_ "status", value_ (statusName status)]
      button_ [type_ "submit"] (toHtml (statusLabel status))

-- | 내용을 고치는 폼입니다.
--
-- 마감일 입력을 비운 채 저장하면 마감일이 지워집니다. 폼은 빈 값도 함께 보내므로
-- 서버가 이를 제거 요청으로 읽습니다.
editForm :: Todo -> Html ()
editForm todo = section_ [class_ "edit"] $ do
  h3_ "고치기"
  form_ [method_ "post", action_ (detailPath todo <> "/edit")] $ do
    input_ [type_ "text", name_ "title", value_ (unTitle (todoTitle todo))]
    input_ [type_ "text", name_ "tags", value_ (tagsValue (todoTags todo))]
    input_ [type_ "date", name_ "due", value_ (dueValue todo)]
    input_ [type_ "text", name_ "list", value_ (listText todo)]
    prioritySelect (todoPriority todo)
    button_ [type_ "submit"] "저장"

-- | 삭제 확인 화면입니다.
--
-- 삭제는 되돌릴 수 없으므로 링크 한 번으로 실행하지 않습니다
-- (@docs/product/invariants.md@의 @PROD-INV-001@). 보관과 다르다는 것도 함께 알립니다
-- (@docs/product/terminology.md@).
deleteConfirmSection :: Todo -> Html ()
deleteConfirmSection todo = do
  h2_ "삭제할까요?"
  p_ (strong_ (toHtml (unTitle (todoTitle todo))))
  p_ "삭제하면 되돌릴 수 없습니다. 기록을 남기려면 대신 보관하십시오."
  form_ [method_ "post", action_ (detailPath todo <> "/delete")] $
    button_ [type_ "submit", class_ "danger"] "삭제합니다"
  p_ (a_ [href_ (detailPath todo)] "돌아가기")

-- | 안내나 오류를 알리는 화면의 본문입니다.
--
-- 저장소 경로, SQL, 스택 추적을 담지 않습니다. 호출하는 쪽이 이미 사용자 문구로
-- 바꾼 문자열만 넘깁니다.
messageSection :: Text -> Html ()
messageSection message = do
  p_ [class_ "message"] (toHtml message)
  p_ (a_ [href_ "/"] "목록으로")

-- 표시 보조 --------------------------------------------------------------------

todoIdText :: Todo -> Text
todoIdText = T.pack . show . unTodoId . todoId

detailPath :: Todo -> Text
detailPath todo = "/todos/" <> todoIdText todo

listText :: Todo -> Text
listText = unListId . todoListId

tagsText :: Set Tag -> Text
tagsText tags
  | Set.null tags = "-"
  | otherwise = T.intercalate " " [unTag t | t <- Set.toAscList tags]

dueText :: Todo -> Text
dueText todo = case todoDueOn todo of
  Nothing -> "-"
  Just day -> T.pack (show day)

-- | 폼 입력에 넣을 값입니다. 표시용 문구와 달리 빈 값은 빈 문자열입니다.
dueValue :: Todo -> Text
dueValue todo = maybe "" (T.pack . show) (todoDueOn todo)

tagsValue :: Set Tag -> Text
tagsValue tags = T.intercalate " " [unTag t | t <- Set.toAscList tags]

styleSheet :: Text
styleSheet =
  "body { font-family: system-ui, sans-serif; margin: 2rem auto; max-width: 52rem; padding: 0 1rem; }\n\
  \header h1 { font-size: 1.25rem; }\n\
  \header h1 a { color: inherit; text-decoration: none; }\n\
  \table { border-collapse: collapse; width: 100%; }\n\
  \th, td { text-align: left; padding: 0.4rem 0.6rem; border-bottom: 1px solid #ddd; }\n\
  \th { font-weight: 600; font-size: 0.85rem; }\n\
  \nav.filters { margin-bottom: 1rem; font-size: 0.9rem; }\n\
  \nav.filters a, nav.filters .current { margin-right: 0.75rem; }\n\
  \nav.filters .current { font-weight: 700; text-decoration: none; color: inherit; }\n\
  \dl { display: grid; grid-template-columns: 6rem 1fr; gap: 0.3rem 1rem; }\n\
  \dt { font-weight: 600; }\n\
  \.empty, .message { color: #555; }\n\
  \form.create { display: flex; gap: 0.4rem; margin-bottom: 1rem; flex-wrap: wrap; }\n\
  \form.create input[name=\"title\"] { flex: 1 1 12rem; }\n\
  \section.transitions form { display: inline; margin-right: 0.4rem; }\n\
  \section.edit form { display: flex; gap: 0.4rem; flex-wrap: wrap; margin-bottom: 1rem; }\n\
  \h3 { font-size: 0.95rem; margin: 1.2rem 0 0.5rem; }\n\
  \p.actions a { margin-right: 0.75rem; }\n\
  \.danger { color: #a11; }\n"
