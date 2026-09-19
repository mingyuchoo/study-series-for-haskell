{-# LANGUAGE OverloadedStrings #-}

-- | HTML 표현입니다.
--
-- 이 모듈이 브라우저 표면의 전송 표현을 소유합니다. 도메인 타입에 렌더링 인스턴스를
-- 붙이지 않는 것은 @Todo.Api.Types@가 JSON에 대해 따르는 원칙과 같습니다
-- (@docs/decisions/ADR-0003-api-boundary.md@).
--
-- 이 모듈은 규칙을 판단하지 않습니다. 목록의 내용과 순서는 "Todo.Core.Filter"가
-- 정한 결과를 그대로 받아 표시하고, 여기서 다시 거르거나 정렬하지 않습니다.
--
-- 웹 UI/UX는 @DESIGN.md@의 Saniti 디자인 시스템(dark-first, oversized editorial
-- display, IBM Plex Mono technical eyebrows, studio-window chrome, coral-red
-- signature accent)을 구현합니다.
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
    header_ [class_ "nav-bar-dark"] $ do
      div_ [class_ "nav-container"] $ do
        div_ [class_ "brand-lockup"] $ do
          span_ [class_ "brand-dot"] mempty
          h1_ [class_ "brand-wordmark"] $ a_ [href_ "/"] (toHtml title)
          span_ [class_ "brand-badge"] "STUDIO"
        div_ [class_ "nav-meta"] $ do
          span_ [class_ "status-pill-mono"] $ do
            span_ [class_ "pulse-dot"] mempty
            "127.0.0.1 : LOOPBACK"
    main_ [class_ "main-container"] body_'
    footer_ [class_ "footer-dark"] $ do
      div_ [class_ "footer-container"] $ do
        div_ [class_ "footer-top"] $ do
          div_ [class_ "footer-brand"] $ do
            span_ [class_ "brand-dot sm"] mempty
            span_ [class_ "footer-wordmark"] "SANITI // TODO HARNESS"
          div_ [class_ "footer-eyebrows"] $ do
            span_ [class_ "footer-eyebrow"] "LOCAL-FIRST ENGINE // ZERO REMOTE ASSETS"
        div_ [class_ "footer-bottom"] $ do
          span_ [class_ "footer-copy"] "STRUCTURE POWERS INTELLIGENCE. ALL DATA PERSISTED TO LOCAL SQLITE."

-- | Studio 스타일 프레임 컴포넌트입니다.
--
-- DESIGN.md의 @studio-window@ 명세를 반영해 3색 윈도우 컨트롤 닷과 모노 제목 바를 가집니다.
studioWindow :: Text -> Html () -> Html ()
studioWindow winTitle content =
  div_ [class_ "studio-window"] $ do
    div_ [class_ "window-chrome"] $ do
      div_ [class_ "window-dots"] $ do
        span_ [class_ "window-dot dot-red"] mempty
        span_ [class_ "window-dot dot-yellow"] mempty
        span_ [class_ "window-dot dot-green"] mempty
      span_ [class_ "window-title"] (toHtml winTitle)
      span_ [class_ "window-meta"] "LOCAL ENGINE"
    div_ [class_ "window-content"] content

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
filterBar selected showAll = div_ [class_ "filter-section"] $ do
  div_ [class_ "mono-eyebrow"] "VIEW // STATUS FILTER"
  nav_ [class_ "filters"] $ do
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
  input_ [type_ "text", name_ "title", placeholder_ "할 일", required_ "required", class_ "input-title"]
  input_ [type_ "text", name_ "tags", placeholder_ "태그 (공백으로 구분)", class_ "input-tags"]
  input_ [type_ "date", name_ "due", class_ "input-due"]
  prioritySelect Normal
  button_ [type_ "submit", class_ "button-brand"] "추가"

-- | 우선순위 고르기입니다. 값은 표시 문구가 아니라 @priorityName@입니다.
prioritySelect :: Priority -> Html ()
prioritySelect selected = select_ [name_ "priority", class_ "select-priority"] (mapM_ option [minBound .. maxBound])
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
  div_ [class_ "hero-section"] $ do
    div_ [class_ "mono-eyebrow"] "TASK REPOSITORY // LOCAL HARNESS"
    h2_ [class_ "hero-headline"] "Structure powers intelligence"
    p_ [class_ "hero-subtitle"] "A dark-first, high-conviction task harness backed by SQLite and pure domain rules."
  studioWindow "NEW_TASK_ENTRY" createForm
  bar
  studioWindow "TASKS_REGISTRY.table" $
    if null todos
      then p_ [class_ "empty"] "조건에 맞는 할 일이 없습니다."
      else div_ [class_ "table-responsive"] $
        table_ [class_ "task-table"] $ do
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
todoRow todo = tr_ [class_ "task-row"] $ do
  td_ [class_ "col-id"] (span_ [class_ "mono-id"] (toHtml (todoIdText todo)))
  td_ [class_ "col-status"] (span_ [class_ ("status-badge status-" <> statusName (todoStatus todo))] (toHtml (statusLabel (todoStatus todo))))
  td_ [class_ "col-title"] (a_ [href_ (detailPath todo), class_ "task-link"] (toHtml (unTitle (todoTitle todo))))
  td_ [class_ "col-priority"] (span_ [class_ ("priority-badge priority-" <> priorityName (todoPriority todo))] (toHtml (priorityLabel (todoPriority todo))))
  td_ [class_ "col-tags"] $
    if Set.null (todoTags todo)
      then span_ [class_ "tags-empty"] "-"
      else div_ [class_ "tags-list"] $ mapM_ (\t -> span_ [class_ "tag-chip"] (toHtml (unTag t))) (Set.toAscList (todoTags todo))
  td_ [class_ "col-due"] (span_ [class_ "mono-due"] (toHtml (dueText todo)))

-- | 상세 화면의 본문입니다.
--
-- 상태 변경 단추는 'allowed'가 넘겨준 목록만 보여줍니다. 어떤 전이가 가능한지는
-- "Todo.Core.Status"가 답하며 이 모듈은 판단하지 않습니다.
todoDetailSection :: [Status] -> Todo -> Html ()
todoDetailSection allowed todo =
  studioWindow ("TASK_SPECIFICATION // ID " <> todoIdText todo) $ do
    div_ [class_ "detail-container"] $ do
      div_ [class_ "task-header"] $ do
        div_ [class_ "mono-eyebrow"] "TASK RECORD // METADATA"
        h2_ [class_ "task-title"] (toHtml (unTitle (todoTitle todo)))
      dl_ [class_ "task-meta"] $ do
        field "번호" (todoIdText todo)
        field "상태" (statusLabel (todoStatus todo))
        field "우선순위" (priorityLabel (todoPriority todo))
        field "목록" (listText todo)
        field "태그" (tagsText (todoTags todo))
        field "마감" (dueText todo)
      statusForms allowed todo
      editForm todo
      p_ [class_ "actions"] $ do
        a_ [href_ "/", class_ "button-ghost-dark"] "목록으로"
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
      div_ [class_ "transition-buttons"] (mapM_ statusButton allowed)
 where
  statusButton :: Status -> Html ()
  statusButton status =
    form_ [method_ "post", action_ (detailPath todo <> "/status")] $ do
      input_ [type_ "hidden", name_ "status", value_ (statusName status)]
      button_ [type_ "submit", class_ "button-secondary-dark"] (toHtml (statusLabel status))

-- | 내용을 고치는 폼입니다.
--
-- 마감일 입력을 비운 채 저장하면 마감일이 지워집니다. 폼은 빈 값도 함께 보내므로
-- 서버가 이를 제거 요청으로 읽습니다.
editForm :: Todo -> Html ()
editForm todo = section_ [class_ "edit"] $ do
  h3_ "고치기"
  form_ [method_ "post", action_ (detailPath todo <> "/edit")] $ do
    div_ [class_ "edit-grid"] $ do
      div_ [class_ "field-group"] $ do
        label_ [for_ "edit-title"] "제목"
        input_ [id_ "edit-title", type_ "text", name_ "title", value_ (unTitle (todoTitle todo))]
      div_ [class_ "field-group"] $ do
        label_ [for_ "edit-tags"] "태그"
        input_ [id_ "edit-tags", type_ "text", name_ "tags", value_ (tagsValue (todoTags todo))]
      div_ [class_ "field-group"] $ do
        label_ [for_ "edit-due"] "마감일"
        input_ [id_ "edit-due", type_ "date", name_ "due", value_ (dueValue todo)]
      div_ [class_ "field-group"] $ do
        label_ [for_ "edit-list"] "목록"
        input_ [id_ "edit-list", type_ "text", name_ "list", value_ (listText todo)]
      div_ [class_ "field-group"] $ do
        label_ [for_ "edit-priority"] "우선순위"
        prioritySelect (todoPriority todo)
    button_ [type_ "submit", class_ "button-primary"] "저장"

-- | 삭제 확인 화면입니다.
--
-- 삭제는 되돌릴 수 없으므로 링크 한 번으로 실행하지 않습니다
-- (@docs/product/invariants.md@의 @PROD-INV-001@). 보관과 다르다는 것도 함께 알립니다
-- (@docs/product/terminology.md@).
deleteConfirmSection :: Todo -> Html ()
deleteConfirmSection todo =
  studioWindow "CRITICAL_ACTION // CONFIRMATION REQUIRED" $ do
    div_ [class_ "danger-card"] $ do
      div_ [class_ "mono-eyebrow"] "DESTRUCTIVE DISPOSITION"
      h2_ [class_ "danger-title"] "삭제할까요?"
      p_ [class_ "target-title"] (strong_ (toHtml (unTitle (todoTitle todo))))
      div_ [class_ "warning-box"] $ do
        p_ "삭제하면 되돌릴 수 없습니다. 기록을 남기려면 대신 보관하십시오."
      form_ [method_ "post", action_ (detailPath todo <> "/delete")] $
        button_ [type_ "submit", class_ "danger"] "삭제합니다"
      p_ [class_ "actions"] $
        a_ [href_ (detailPath todo), class_ "button-ghost-dark"] "돌아가기"

-- | 안내나 오류를 알리는 화면의 본문입니다.
--
-- 저장소 경로, SQL, 스택 추적을 담지 않습니다. 호출하는 쪽이 이미 사용자 문구로
-- 바꾼 문자열만 넘깁니다.
messageSection :: Text -> Html ()
messageSection message =
  studioWindow "SYSTEM_NOTIFICATION" $ do
    div_ [class_ "message-card"] $ do
      div_ [class_ "mono-eyebrow"] "SYSTEM NOTIFICATION"
      p_ [class_ "message"] (toHtml message)
      p_ [class_ "actions"] $
        a_ [href_ "/", class_ "button-primary"] "목록으로"

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

-- | Saniti 디자인 시스템 스타일시트입니다.
--
-- 외부 원격 자산을 전혀 참조하지 않고, 로컬 전용 서체 스택과 디자인 토큰을 정의합니다.
styleSheet :: Text
styleSheet =
  T.unlines
    [ ":root {"
    , "  --canvas: #0b0b0b;"
    , "  --canvas-soft: #212121;"
    , "  --canvas-light: #ffffff;"
    , "  --canvas-paper: #ededed;"
    , "  --on-primary: #ffffff;"
    , "  --ink: #0b0b0b;"
    , "  --ink-soft: #212121;"
    , "  --brand: #f36458;"
    , "  --brand-deep: #dd0000;"
    , "  --graphite: #353535;"
    , "  --slate: #3c4758;"
    , "  --slate-soft: #505b6c;"
    , "  --mute: #797979;"
    , "  --ash: #b9b9b9;"
    , "  --hairline: #ededed;"
    , "  --hairline-soft: #353535;"
    , "  --link-blue: #0052ef;"
    , "  --link-blue-soft: #55beff;"
    , "  --surface-blue-bg: #afe3ff;"
    , "  --success: #37cd84;"
    , "  --error: #dd0000;"
    , "  --font-sans: waldenburgNormal, 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', sans-serif;"
    , "  --font-mono: 'IBM Plex Mono', 'SF Mono', Menlo, Monaco, Consolas, 'Liberation Mono', monospace;"
    , "  --radius-xs: 3px;"
    , "  --radius-sm: 4px;"
    , "  --radius-md: 5px;"
    , "  --radius-lg: 6px;"
    , "  --radius-marketing: 12px;"
    , "  --radius-full: 99999px;"
    , "  --space-xxs: 4px;"
    , "  --space-xs: 8px;"
    , "  --space-sm: 12px;"
    , "  --space-md: 16px;"
    , "  --space-lg: 24px;"
    , "  --space-xl: 32px;"
    , "  --space-xxl: 48px;"
    , "  --space-section: 64px;"
    , "  --space-section-lg: 96px;"
    , "}"
    , "*, *::before, *::after {"
    , "  box-sizing: border-box;"
    , "}"
    , "body {"
    , "  margin: 0;"
    , "  padding: 0;"
    , "  background-color: var(--canvas);"
    , "  color: var(--ash);"
    , "  font-family: var(--font-sans);"
    , "  font-size: 16px;"
    , "  line-height: 1.5;"
    , "  -webkit-font-smoothing: antialiased;"
    , "  -moz-osx-font-smoothing: grayscale;"
    , "}"
    , "header.nav-bar-dark {"
    , "  background-color: rgba(11, 11, 11, 0.95);"
    , "  border-bottom: 1px solid var(--hairline-soft);"
    , "  height: 64px;"
    , "  position: sticky;"
    , "  top: 0;"
    , "  z-index: 100;"
    , "  backdrop-filter: blur(8px);"
    , "  padding: 0 var(--space-lg);"
    , "  display: flex;"
    , "  align-items: center;"
    , "}"
    , ".nav-container {"
    , "  max-width: 1140px;"
    , "  width: 100%;"
    , "  margin: 0 auto;"
    , "  display: flex;"
    , "  align-items: center;"
    , "  justify-content: space-between;"
    , "}"
    , ".brand-lockup {"
    , "  display: flex;"
    , "  align-items: center;"
    , "  gap: 8px;"
    , "}"
    , ".brand-dot {"
    , "  width: 12px;"
    , "  height: 12px;"
    , "  background-color: var(--brand);"
    , "  border-radius: var(--radius-full);"
    , "  display: inline-block;"
    , "  flex-shrink: 0;"
    , "  box-shadow: 0 0 10px rgba(243, 100, 88, 0.4);"
    , "}"
    , ".brand-dot.sm {"
    , "  width: 10px;"
    , "  height: 10px;"
    , "  box-shadow: none;"
    , "}"
    , ".brand-wordmark {"
    , "  margin: 0;"
    , "  font-size: 18px;"
    , "  font-weight: 500;"
    , "  letter-spacing: -0.5px;"
    , "}"
    , ".brand-wordmark a {"
    , "  color: var(--on-primary);"
    , "  text-decoration: none;"
    , "}"
    , ".brand-badge {"
    , "  font-family: var(--font-mono);"
    , "  font-size: 10px;"
    , "  color: var(--mute);"
    , "  text-transform: uppercase;"
    , "  letter-spacing: 0.08em;"
    , "  padding: 2px 6px;"
    , "  background: var(--canvas-soft);"
    , "  border: 1px solid var(--hairline-soft);"
    , "  border-radius: var(--radius-xs);"
    , "  margin-left: 6px;"
    , "}"
    , ".nav-meta {"
    , "  display: flex;"
    , "  align-items: center;"
    , "  gap: 12px;"
    , "}"
    , ".status-pill-mono {"
    , "  display: inline-flex;"
    , "  align-items: center;"
    , "  gap: 8px;"
    , "  font-family: var(--font-mono);"
    , "  font-size: 11px;"
    , "  color: var(--mute);"
    , "  background: var(--canvas-soft);"
    , "  border: 1px solid var(--hairline-soft);"
    , "  padding: 4px 12px;"
    , "  border-radius: var(--radius-full);"
    , "}"
    , ".pulse-dot {"
    , "  width: 6px;"
    , "  height: 6px;"
    , "  background-color: var(--success);"
    , "  border-radius: 50%;"
    , "  display: inline-block;"
    , "  box-shadow: 0 0 6px rgba(55, 205, 132, 0.6);"
    , "}"
    , ".main-container {"
    , "  max-width: 1140px;"
    , "  margin: 0 auto;"
    , "  padding: var(--space-xl) var(--space-lg) var(--space-section);"
    , "}"
    , ".hero-section {"
    , "  margin-bottom: var(--space-xl);"
    , "}"
    , ".mono-eyebrow {"
    , "  font-family: var(--font-mono);"
    , "  font-size: 13px;"
    , "  line-height: 1.5;"
    , "  letter-spacing: 0.05em;"
    , "  text-transform: uppercase;"
    , "  color: var(--mute);"
    , "  margin-bottom: var(--space-xs);"
    , "}"
    , ".hero-headline {"
    , "  font-size: 48px;"
    , "  line-height: 1.08;"
    , "  letter-spacing: -1.68px;"
    , "  font-weight: 400;"
    , "  color: var(--on-primary);"
    , "  margin: 0 0 var(--space-xs) 0;"
    , "}"
    , ".hero-subtitle {"
    , "  font-size: 18px;"
    , "  line-height: 1.5;"
    , "  letter-spacing: -0.18px;"
    , "  color: var(--ash);"
    , "  margin: 0;"
    , "  max-width: 640px;"
    , "}"
    , ".studio-window {"
    , "  background-color: var(--canvas-soft);"
    , "  border: 1px solid var(--hairline-soft);"
    , "  border-radius: var(--radius-lg);"
    , "  overflow: hidden;"
    , "  margin-bottom: var(--space-lg);"
    , "  box-shadow: 0 16px 32px rgba(0, 0, 0, 0.45);"
    , "}"
    , ".window-chrome {"
    , "  background-color: #181818;"
    , "  border-bottom: 1px solid var(--hairline-soft);"
    , "  padding: 10px 16px;"
    , "  display: flex;"
    , "  align-items: center;"
    , "  justify-content: space-between;"
    , "}"
    , ".window-dots {"
    , "  display: flex;"
    , "  gap: 7px;"
    , "  align-items: center;"
    , "}"
    , ".window-dot {"
    , "  width: 10px;"
    , "  height: 10px;"
    , "  border-radius: 50%;"
    , "}"
    , ".dot-red {"
    , "  background-color: var(--brand);"
    , "}"
    , ".dot-yellow {"
    , "  background-color: #f5a623;"
    , "}"
    , ".dot-green {"
    , "  background-color: var(--success);"
    , "}"
    , ".window-title {"
    , "  font-family: var(--font-mono);"
    , "  font-size: 11px;"
    , "  color: var(--mute);"
    , "  text-transform: uppercase;"
    , "  letter-spacing: 0.06em;"
    , "}"
    , ".window-meta {"
    , "  font-family: var(--font-mono);"
    , "  font-size: 10px;"
    , "  color: var(--graphite);"
    , "}"
    , ".window-content {"
    , "  padding: var(--space-lg);"
    , "}"
    , "form.create {"
    , "  display: flex;"
    , "  gap: var(--space-sm);"
    , "  flex-wrap: wrap;"
    , "  align-items: center;"
    , "}"
    , "form.create input[name='title'] {"
    , "  flex: 2 1 18rem;"
    , "}"
    , "form.create input[name='tags'] {"
    , "  flex: 1 1 12rem;"
    , "}"
    , "form.create input[name='due'] {"
    , "  flex: 0 1 10rem;"
    , "}"
    , "form.create select[name='priority'] {"
    , "  flex: 0 1 8rem;"
    , "}"
    , "input[type='text'], input[type='date'], select {"
    , "  background-color: var(--canvas);"
    , "  color: var(--on-primary);"
    , "  border: 1px solid var(--hairline-soft);"
    , "  border-radius: var(--radius-xs);"
    , "  padding: 10px 14px;"
    , "  font-size: 14px;"
    , "  font-family: var(--font-sans);"
    , "  height: 42px;"
    , "  box-sizing: border-box;"
    , "  outline: none;"
    , "  transition: border-color 0.15s ease, box-shadow 0.15s ease;"
    , "}"
    , "input[type='date'] {"
    , "  color-scheme: dark;"
    , "  font-family: var(--font-mono);"
    , "  font-size: 13px;"
    , "}"
    , "select {"
    , "  color-scheme: dark;"
    , "}"
    , "input[type='text']:focus, input[type='date']:focus, select:focus {"
    , "  border-color: var(--link-blue-soft);"
    , "  box-shadow: 0 0 0 2px rgba(85, 190, 255, 0.2);"
    , "}"
    , "input[type='text']::placeholder {"
    , "  color: var(--mute);"
    , "}"
    , ".button-brand, button.button-brand, form.create button[type='submit'] {"
    , "  background-color: var(--brand);"
    , "  color: var(--ink);"
    , "  font-family: var(--font-sans);"
    , "  font-size: 15px;"
    , "  font-weight: 600;"
    , "  border-radius: var(--radius-full);"
    , "  padding: 0 24px;"
    , "  height: 42px;"
    , "  border: none;"
    , "  cursor: pointer;"
    , "  transition: all 0.15s ease;"
    , "  display: inline-flex;"
    , "  align-items: center;"
    , "  justify-content: center;"
    , "  flex-shrink: 0;"
    , "}"
    , ".button-brand:hover, button.button-brand:hover, form.create button[type='submit']:hover {"
    , "  background-color: #ff786e;"
    , "  transform: translateY(-1px);"
    , "  box-shadow: 0 4px 12px rgba(243, 100, 88, 0.35);"
    , "}"
    , ".button-primary, button.button-primary {"
    , "  background-color: var(--canvas-light);"
    , "  color: var(--ink);"
    , "  font-family: var(--font-sans);"
    , "  font-size: 14px;"
    , "  font-weight: 600;"
    , "  border-radius: var(--radius-full);"
    , "  padding: 9px 22px;"
    , "  border: none;"
    , "  cursor: pointer;"
    , "  transition: all 0.15s ease;"
    , "  text-decoration: none;"
    , "  display: inline-flex;"
    , "  align-items: center;"
    , "}"
    , ".button-primary:hover, button.button-primary:hover {"
    , "  background-color: var(--ash);"
    , "}"
    , ".button-secondary-dark, button.button-secondary-dark, section.transitions button {"
    , "  background-color: var(--canvas-soft);"
    , "  color: var(--on-primary);"
    , "  border: 1px solid var(--hairline-soft);"
    , "  border-radius: var(--radius-md);"
    , "  padding: 8px 18px;"
    , "  font-size: 13px;"
    , "  font-weight: 500;"
    , "  cursor: pointer;"
    , "  transition: all 0.15s ease;"
    , "  font-family: var(--font-sans);"
    , "}"
    , ".button-secondary-dark:hover, button.button-secondary-dark:hover, section.transitions button:hover {"
    , "  background-color: var(--canvas-light);"
    , "  color: var(--ink);"
    , "  border-color: var(--canvas-light);"
    , "}"
    , ".button-ghost-dark, a.button-ghost-dark {"
    , "  background-color: transparent;"
    , "  color: var(--ash);"
    , "  border: 1px solid var(--hairline-soft);"
    , "  border-radius: var(--radius-full);"
    , "  padding: 8px 18px;"
    , "  font-size: 13px;"
    , "  font-weight: 500;"
    , "  text-decoration: none;"
    , "  transition: all 0.15s ease;"
    , "  display: inline-flex;"
    , "  align-items: center;"
    , "}"
    , ".button-ghost-dark:hover, a.button-ghost-dark:hover {"
    , "  color: var(--on-primary);"
    , "  border-color: var(--slate-soft);"
    , "  background-color: #2b2b2b;"
    , "}"
    , ".filter-section {"
    , "  margin: var(--space-xl) 0 var(--space-md);"
    , "}"
    , "nav.filters {"
    , "  display: flex;"
    , "  align-items: center;"
    , "  gap: var(--space-xs);"
    , "  flex-wrap: wrap;"
    , "}"
    , "nav.filters a, nav.filters .current {"
    , "  display: inline-flex;"
    , "  align-items: center;"
    , "  height: 34px;"
    , "  padding: 0 14px;"
    , "  border-radius: var(--radius-full);"
    , "  font-size: 13px;"
    , "  text-decoration: none;"
    , "  transition: all 0.15s ease;"
    , "}"
    , "nav.filters a {"
    , "  background-color: var(--canvas-soft);"
    , "  color: var(--ash);"
    , "  border: 1px solid var(--hairline-soft);"
    , "  font-weight: 500;"
    , "}"
    , "nav.filters a:hover {"
    , "  color: var(--on-primary);"
    , "  border-color: var(--slate-soft);"
    , "  background-color: #2b2b2b;"
    , "}"
    , "nav.filters .current {"
    , "  background-color: var(--canvas-light);"
    , "  color: var(--ink);"
    , "  border: 1px solid var(--canvas-light);"
    , "  font-weight: 600;"
    , "  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.4);"
    , "}"
    , ".table-responsive {"
    , "  overflow-x: auto;"
    , "}"
    , "table {"
    , "  width: 100%;"
    , "  border-collapse: collapse;"
    , "  font-size: 14px;"
    , "}"
    , "thead tr {"
    , "  background-color: #161616;"
    , "  border-bottom: 1px solid var(--hairline-soft);"
    , "}"
    , "th {"
    , "  font-family: var(--font-mono);"
    , "  font-size: 11px;"
    , "  font-weight: 400;"
    , "  text-transform: uppercase;"
    , "  letter-spacing: 0.06em;"
    , "  color: var(--mute);"
    , "  padding: 12px 16px;"
    , "  text-align: left;"
    , "}"
    , "tbody tr {"
    , "  border-bottom: 1px solid #282828;"
    , "  transition: background-color 0.12s ease;"
    , "}"
    , "tbody tr:hover {"
    , "  background-color: rgba(255, 255, 255, 0.025);"
    , "}"
    , "td {"
    , "  padding: 14px 16px;"
    , "  color: var(--ash);"
    , "  vertical-align: middle;"
    , "}"
    , ".col-id, .mono-id {"
    , "  font-family: var(--font-mono);"
    , "  font-size: 12px;"
    , "  color: var(--mute);"
    , "}"
    , ".col-title a, .task-link {"
    , "  color: var(--on-primary);"
    , "  text-decoration: none;"
    , "  font-weight: 500;"
    , "  font-size: 15px;"
    , "  transition: color 0.12s ease;"
    , "}"
    , ".col-title a:hover, .task-link:hover {"
    , "  color: var(--link-blue-soft);"
    , "  text-decoration: underline;"
    , "}"
    , ".status-badge {"
    , "  display: inline-flex;"
    , "  align-items: center;"
    , "  padding: 3px 10px;"
    , "  border-radius: var(--radius-full);"
    , "  font-size: 11px;"
    , "  font-family: var(--font-mono);"
    , "  font-weight: 500;"
    , "  letter-spacing: 0.02em;"
    , "}"
    , ".status-pending {"
    , "  background-color: #1c1c1c;"
    , "  color: var(--ash);"
    , "  border: 1px solid var(--hairline-soft);"
    , "}"
    , ".status-in_progress {"
    , "  background-color: rgba(85, 190, 255, 0.1);"
    , "  color: var(--link-blue-soft);"
    , "  border: 1px solid rgba(85, 190, 255, 0.35);"
    , "}"
    , ".status-done {"
    , "  background-color: rgba(55, 205, 132, 0.1);"
    , "  color: var(--success);"
    , "  border: 1px solid rgba(55, 205, 132, 0.35);"
    , "}"
    , ".status-archived {"
    , "  background-color: #171717;"
    , "  color: var(--slate-soft);"
    , "  border: 1px solid #2e3540;"
    , "}"
    , ".priority-badge {"
    , "  display: inline-flex;"
    , "  align-items: center;"
    , "  font-size: 11px;"
    , "  font-family: var(--font-mono);"
    , "  border-radius: var(--radius-full);"
    , "  padding: 2px 8px;"
    , "}"
    , ".priority-urgent {"
    , "  background-color: rgba(243, 100, 88, 0.16);"
    , "  color: var(--brand);"
    , "  border: 1px solid var(--brand);"
    , "  font-weight: 600;"
    , "}"
    , ".priority-high {"
    , "  background-color: rgba(245, 166, 35, 0.12);"
    , "  color: #f5a623;"
    , "  border: 1px solid rgba(245, 166, 35, 0.3);"
    , "}"
    , ".priority-normal {"
    , "  color: var(--mute);"
    , "}"
    , ".priority-low {"
    , "  color: #555555;"
    , "}"
    , ".tags-list {"
    , "  display: flex;"
    , "  gap: 4px;"
    , "  flex-wrap: wrap;"
    , "}"
    , ".tag-chip {"
    , "  font-family: var(--font-mono);"
    , "  font-size: 11px;"
    , "  background-color: #171717;"
    , "  border: 1px solid #2d2d2d;"
    , "  border-radius: var(--radius-xs);"
    , "  padding: 2px 7px;"
    , "  color: var(--ash);"
    , "}"
    , ".tags-empty {"
    , "  color: var(--mute);"
    , "}"
    , ".mono-due {"
    , "  font-family: var(--font-mono);"
    , "  font-size: 12px;"
    , "  color: var(--mute);"
    , "}"
    , ".empty {"
    , "  padding: 56px 24px;"
    , "  text-align: center;"
    , "  color: var(--mute);"
    , "  font-size: 15px;"
    , "  margin: 0;"
    , "}"
    , ".task-header {"
    , "  margin-bottom: var(--space-lg);"
    , "}"
    , ".task-title {"
    , "  font-size: 32px;"
    , "  line-height: 1.13;"
    , "  letter-spacing: -0.32px;"
    , "  font-weight: 425;"
    , "  color: var(--on-primary);"
    , "  margin: 0 0 var(--space-md) 0;"
    , "}"
    , "dl, dl.task-meta {"
    , "  display: grid;"
    , "  grid-template-columns: 8rem 1fr;"
    , "  gap: 14px 20px;"
    , "  background-color: #161616;"
    , "  padding: 24px;"
    , "  border-radius: var(--radius-lg);"
    , "  border: 1px solid var(--hairline-soft);"
    , "  margin: 0 0 var(--space-xl) 0;"
    , "}"
    , "dt {"
    , "  font-family: var(--font-mono);"
    , "  font-size: 11px;"
    , "  text-transform: uppercase;"
    , "  color: var(--mute);"
    , "  letter-spacing: 0.06em;"
    , "  align-self: center;"
    , "}"
    , "dd {"
    , "  font-size: 15px;"
    , "  color: var(--on-primary);"
    , "  margin: 0;"
    , "}"
    , "section.transitions {"
    , "  margin: var(--space-xl) 0;"
    , "}"
    , "section.transitions h3, section.edit h3 {"
    , "  font-family: var(--font-mono);"
    , "  font-size: 12px;"
    , "  text-transform: uppercase;"
    , "  letter-spacing: 0.06em;"
    , "  color: var(--mute);"
    , "  margin: 0 0 var(--space-sm) 0;"
    , "}"
    , "section.transitions form {"
    , "  display: inline-block;"
    , "  margin-right: var(--space-xs);"
    , "  margin-bottom: var(--space-xs);"
    , "}"
    , "section.edit form {"
    , "  display: grid;"
    , "  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));"
    , "  gap: var(--space-sm);"
    , "  background-color: #161616;"
    , "  padding: 24px;"
    , "  border-radius: var(--radius-lg);"
    , "  border: 1px solid var(--hairline-soft);"
    , "}"
    , ".field-group {"
    , "  display: flex;"
    , "  flex-direction: column;"
    , "  gap: 6px;"
    , "}"
    , ".field-group label {"
    , "  font-family: var(--font-mono);"
    , "  font-size: 11px;"
    , "  color: var(--mute);"
    , "  text-transform: uppercase;"
    , "  letter-spacing: 0.05em;"
    , "}"
    , "section.edit button[type='submit'] {"
    , "  grid-column: 1 / -1;"
    , "  justify-self: start;"
    , "  margin-top: var(--space-xs);"
    , "}"
    , "p.actions {"
    , "  display: flex;"
    , "  gap: var(--space-md);"
    , "  align-items: center;"
    , "  border-top: 1px solid var(--hairline-soft);"
    , "  padding-top: var(--space-lg);"
    , "  margin-top: var(--space-xl);"
    , "}"
    , "p.actions a {"
    , "  display: inline-flex;"
    , "  align-items: center;"
    , "  padding: 8px 18px;"
    , "  border-radius: var(--radius-full);"
    , "  font-size: 13px;"
    , "  font-weight: 500;"
    , "  text-decoration: none;"
    , "  transition: all 0.15s ease;"
    , "}"
    , "p.actions a:not(.danger) {"
    , "  background-color: var(--canvas-soft);"
    , "  color: var(--ash);"
    , "  border: 1px solid var(--hairline-soft);"
    , "}"
    , "p.actions a:not(.danger):hover {"
    , "  color: var(--on-primary);"
    , "  border-color: var(--slate-soft);"
    , "  background-color: #2b2b2b;"
    , "}"
    , ".danger, p.actions a.danger {"
    , "  background-color: transparent;"
    , "  color: var(--brand);"
    , "  border: 1px solid rgba(243, 100, 88, 0.4);"
    , "}"
    , ".danger:hover, p.actions a.danger:hover {"
    , "  background-color: var(--brand);"
    , "  color: var(--ink);"
    , "  border-color: var(--brand);"
    , "}"
    , ".danger-card {"
    , "  padding: var(--space-md) 0;"
    , "}"
    , ".danger-title {"
    , "  font-size: 32px;"
    , "  color: var(--on-primary);"
    , "  margin: 0 0 var(--space-sm) 0;"
    , "}"
    , ".target-title {"
    , "  font-size: 18px;"
    , "  color: var(--on-primary);"
    , "  margin-bottom: var(--space-md);"
    , "}"
    , ".warning-box {"
    , "  background-color: rgba(243, 100, 88, 0.08);"
    , "  border-left: 3px solid var(--brand);"
    , "  padding: 16px 20px;"
    , "  border-radius: var(--radius-xs);"
    , "  color: var(--ash);"
    , "  font-size: 14px;"
    , "  line-height: 1.6;"
    , "  margin-bottom: var(--space-lg);"
    , "}"
    , ".warning-box p {"
    , "  margin: 0;"
    , "}"
    , "button.danger {"
    , "  background-color: var(--brand-deep);"
    , "  color: var(--on-primary);"
    , "  font-size: 15px;"
    , "  font-weight: 600;"
    , "  border-radius: var(--radius-full);"
    , "  padding: 12px 28px;"
    , "  border: none;"
    , "  cursor: pointer;"
    , "  transition: opacity 0.15s;"
    , "}"
    , "button.danger:hover {"
    , "  opacity: 0.9;"
    , "}"
    , ".message-card {"
    , "  padding: var(--space-md) 0;"
    , "}"
    , ".message {"
    , "  font-size: 16px;"
    , "  color: var(--on-primary);"
    , "  line-height: 1.6;"
    , "  margin-bottom: var(--space-lg);"
    , "}"
    , "footer.footer-dark {"
    , "  border-top: 1px solid var(--hairline-soft);"
    , "  padding: var(--space-section) var(--space-lg);"
    , "  margin-top: var(--space-section);"
    , "  background-color: var(--canvas);"
    , "}"
    , ".footer-container {"
    , "  max-width: 1140px;"
    , "  margin: 0 auto;"
    , "  display: flex;"
    , "  flex-direction: column;"
    , "  gap: var(--space-md);"
    , "}"
    , ".footer-top {"
    , "  display: flex;"
    , "  justify-content: space-between;"
    , "  align-items: center;"
    , "  flex-wrap: wrap;"
    , "  gap: var(--space-sm);"
    , "}"
    , ".footer-brand {"
    , "  display: flex;"
    , "  align-items: center;"
    , "  gap: 8px;"
    , "}"
    , ".footer-wordmark {"
    , "  font-size: 14px;"
    , "  font-weight: 500;"
    , "  color: var(--on-primary);"
    , "  letter-spacing: -0.2px;"
    , "}"
    , ".footer-eyebrow {"
    , "  font-family: var(--font-mono);"
    , "  font-size: 11px;"
    , "  color: var(--mute);"
    , "  text-transform: uppercase;"
    , "  letter-spacing: 0.06em;"
    , "}"
    , ".footer-bottom {"
    , "  font-family: var(--font-mono);"
    , "  font-size: 11px;"
    , "  color: var(--graphite);"
    , "}"
    , "@media (max-width: 768px) {"
    , "  .hero-headline {"
    , "    font-size: 36px;"
    , "    letter-spacing: -1px;"
    , "  }"
    , "  form.create {"
    , "    flex-direction: column;"
    , "    align-items: stretch;"
    , "  }"
    , "  form.create input[name='title'], form.create input[name='tags'], form.create input[name='due'], form.create select[name='priority'], form.create button[type='submit'] {"
    , "    width: 100%;"
    , "    flex: none;"
    , "  }"
    , "  .studio-window .window-content {"
    , "    padding: var(--space-md);"
    , "  }"
    , "  dl, dl.task-meta {"
    , "    grid-template-columns: 1fr;"
    , "    gap: 8px;"
    , "  }"
    , "  table {"
    , "    display: block;"
    , "    overflow-x: auto;"
    , "  }"
    , "}"
    ]
