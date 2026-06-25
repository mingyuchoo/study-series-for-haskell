-- | Org-mode 본문을 HTML로 렌더링하는 순수 렌더러.
--
-- 블로그 도메인·라우팅과 무관한 독립 단위다('Text' → 'Html'). @org-mode@
-- 라이브러리가 만든 계층형 'Org.OrgDoc' 를 직접 순회하며, (1) 섹션 깊이만큼
-- 본문을 들여쓰고(@org-indent-N@), (2) 리스트 마커(@-@/@+@/번호)별로 글리프
-- 클래스를 달리 부여한다. 실제 글리프·색·들여쓰기 픽셀값은 뷰 계층의 CSS
-- (@.body …@)가 이 클래스 이름 규약에 맞춰 담당한다.
module Blog.Org
  ( renderOrg
  , renderOrgFragment
  ) where

import Data.Char (isDigit)
import Data.Foldable (toList)
import Data.List.NonEmpty (NonEmpty (..))
import Data.Org qualified as Org
import Data.Text (Text)
import Data.Text qualified as T
import Text.Blaze.Html5 (Html, (!))
import Text.Blaze.Html5 qualified as H
import Text.Blaze.Html5.Attributes qualified as A

-- | 글 본문을 Org-mode 문법으로 파싱해 HTML로 렌더링한다.
--   파싱에 실패하면 원본 텍스트를 그대로 보여준다.
renderOrg :: Text -> Html
renderOrg raw = case Org.org (normalizeOrg raw) of
  Just (Org.OrgFile _ doc) -> renderDoc 1 doc
  Nothing                  -> H.toHtml raw

-- | 본문만 Org 로 렌더링한 HTML 조각. 라이브 에디터의 미리보기 fetch 응답에 쓴다.
--   발행 결과와 동일한 렌더러를 거치므로 \"미리보기 == 발행\"이 보장된다.
renderOrgFragment :: Text -> Html
renderOrgFragment = renderOrg

-- | 'Org.OrgDoc' 를 재귀적으로 HTML 로 렌더링한다.
--
-- @depth@ 는 섹션 중첩 깊이(1-기준)다. 이 문서에 직접 담긴 블록들은 직전 헤딩
-- 아래에 놓이므로 그 깊이만큼 들여쓰기(@org-indent-N@)해, Emacs @org-indent-mode@
-- 처럼 헤딩 본문이 헤딩 글자 아래로 정렬되게 한다(최상위 depth 1 은 들여쓰지 않음).
-- 하위 섹션은 @h{depth}@ 헤딩으로 내보낸다.
renderDoc :: Int -> Org.OrgDoc -> Html
renderDoc depth (Org.OrgDoc blocks sections) = do
  mapM_ (withIndent depth renderBlock) blocks
  mapM_ (renderSection depth) sections

-- | 섹션 = @h{depth}@ 헤딩 + (depth+1 로 한 단계 더 들여쓴) 본문.
renderSection :: Int -> Org.Section -> Html
renderSection depth (Org.Section _ _ heading _ _ _ _ _ _ doc) = do
  renderHeading depth heading
  renderDoc (depth + 1) doc

-- | 섹션 깊이를 HTML 헤딩 레벨로 — @*@ → h1 … @******@ → h6(그 이상은 h6 클램프).
--   불릿 글리프·색·크기·들여쓰기는 뷰 CSS 의 @.body hN::before@ 가 담당한다.
renderHeading :: Int -> NonEmpty Org.Words -> Html
renderHeading depth ws = tag (renderWords ws)
  where
    tag = case min depth 6 of
      1 -> H.h1
      2 -> H.h2
      3 -> H.h3
      4 -> H.h4
      5 -> H.h5
      _ -> H.h6

-- | 블록을 깊이에 맞춰 들여쓰는 컨테이너(@org-indent-N@)로 감싼다.
--   최상위(depth 1)는 감싸지 않아 기존처럼 좌측 정렬된다.
withIndent :: Int -> (a -> Html) -> a -> Html
withIndent depth render x
  | depth <= 1 = render x
  | otherwise =
      H.div ! A.class_ (H.toValue ("org-indent-" <> show (min depth 6 :: Int))) $ render x

-- | 한 블록을 HTML 로. 인라인 서식·코드·표·인용은 OrgLucid 의 동작을 따른다.
renderBlock :: Org.Block -> Html
renderBlock b = case b of
  Org.Quote t      -> H.blockquote $ mapM_ (H.p . H.toHtml) (T.splitOn "\n\n" t)
  Org.Example t    -> H.pre (H.toHtml t)
  Org.Code ml t    -> renderCode ml t
  Org.List items   -> renderList items
  Org.Table rows   -> renderTable rows
  Org.Paragraph ws -> H.p (renderWords ws)

-- | 리스트. 마커별로 글리프를 달리한다 — @-@(Bulleted)·@+@(Plussed)·번호(Numbered).
--   글리프 치환은 뷰 CSS 의 @.body ul.org-bulleted/​org-plussed li::before@ 가 한다.
renderList :: Org.ListItems -> Html
renderList (Org.ListItems t items) = tag ! A.class_ cls $ mapM_ renderItem items
  where
    (tag, cls) = case t of
      Org.Numbered -> (H.ol, "org-ol")
      Org.Bulleted -> (H.ul, "org-ul org-bulleted")
      Org.Plussed  -> (H.ul, "org-ul org-plussed")
    renderItem (Org.Item ws next) =
      H.li $ renderWords ws <> maybe mempty renderList next

-- | @#+begin_src@ 블록 — Emacs HTML export 와 같은 @div.org-src-container > pre.src@ 구조.
renderCode :: Maybe Org.Language -> Text -> Html
renderCode ml t =
  H.div ! A.class_ "org-src-container" $
    H.pre ! A.class_ (H.toValue cls) $
      H.toHtml t
  where
    cls = T.unwords ("src" : maybe [] (\(Org.Language l) -> ["src-" <> l]) ml)

-- | 표. 첫 비-구분선 행을 헤더로, 나머지를 본문으로 — OrgLucid 의 동작을 따른다.
renderTable :: NonEmpty Org.Row -> Html
renderTable rows = H.table $ do
  H.thead $ H.tr $ maybe mempty (mapM_ headerCell) header
  H.tbody $ mapM_ bodyRow rest
  where
    (header, rest) = splitHeader (toList rows)
    splitHeader []               = (Nothing, [])
    splitHeader (Org.Break : r)  = splitHeader r
    splitHeader (Org.Row cs : r) = (Just cs, r)

    headerCell Org.Empty       = H.th ! A.scope "col" $ mempty
    headerCell (Org.Column ws) = H.th ! A.scope "col" $ renderWords ws

    bodyRow Org.Break    = mempty
    bodyRow (Org.Row cs) = H.tr $ mapM_ bodyCell cs

    bodyCell Org.Empty       = H.td mempty
    bodyCell (Org.Column ws) = H.td $ renderWords ws

-- | 인라인 단어열. 단어 사이 공백 삽입 규칙은 OrgLucid 의 @paragraphHTML@ 과 같게,
--   여는 괄호 직후와 구두점 앞에서는 공백을 넣지 않는다.
renderWords :: NonEmpty Org.Words -> Html
renderWords (firstW :| rest) = renderWord firstW <> go firstW rest
  where
    go _ [] = mempty
    go prev (w : ws) = case prev of
      Org.Punct '(' -> renderWord w <> go w ws
      _ -> case w of
        Org.Punct '(' -> space <> renderWord w <> go w ws
        Org.Punct _   -> renderWord w <> go w ws
        _             -> space <> renderWord w <> go w ws
    space = H.toHtml (" " :: Text)

-- | 한 단어(서식 단위)를 HTML 로 — OrgLucid 의 @wordsHTML@ 와 같은 매핑.
renderWord :: Org.Words -> Html
renderWord w = case w of
  Org.Bold t -> H.b (H.toHtml t)
  Org.Italic t -> H.i (H.toHtml t)
  Org.Highlight t -> H.code ! A.class_ "org-highlight" $ H.toHtml t
  Org.Underline t -> H.span ! A.style "text-decoration: underline;" $ H.toHtml t
  Org.Verbatim t -> H.toHtml t
  Org.Strike t -> H.span ! A.style "text-decoration: line-through;" $ H.toHtml t
  Org.Link (Org.URL u) mt -> H.a ! A.href (H.toValue u) $ maybe mempty H.toHtml mt
  Org.Image (Org.URL u) -> H.figure (H.img ! A.src (H.toValue u))
  Org.Punct c -> H.toHtml (T.singleton c)
  Org.Plain t -> H.toHtml t

-- | 헤딩·리스트 시작 줄 앞에 필요한 빈 줄을 보강하고(='go'), 문서를 여는
--   블록 지시자가 메타 파서에 삼켜지지 않게 보호한다(='fixLeadingBlock').
--
-- @org-mode@ 라이브러리의 문단·리스트 파서는 빈 줄로 구분되지 않은 다음 줄을
-- 직전 블록의 연속 텍스트로 흡수한다. 그래서 (1) @-@ 항목 바로 뒤의 @**@ 헤딩이
-- 헤딩으로 인식되지 못하고, (2) 문단 바로 뒤의 @-@/@+@ 줄이 리스트가 아니라 문단
-- 꼬리로 빨려든다. Emacs org-mode 에서는 헤딩이 빈 줄 없이도 리스트를 끝내고,
-- 불릿 줄은 문단 한가운데서도 새 리스트를 시작한다. 파싱 직전에 빈 줄을 보강해
-- 그 의미론에 맞춘다.
normalizeOrg :: Text -> Text
normalizeOrg = T.intercalate "\n" . fixLeadingBlock . go . T.splitOn "\n"
  where
    go (prev : cur : rest)
      | needsBlank prev cur = prev : "" : go (cur : rest)
      | otherwise = prev : go (cur : rest)
    go xs = xs

    -- 직전 줄이 비어있지 않을 때, cur 앞에 빈 줄이 필요한가.
    needsBlank :: Text -> Text -> Bool
    needsBlank prev cur
      | blank prev = False
      -- 헤딩은 무엇 뒤에 오든 빈 줄로 끊어 헤딩으로 인식시킨다.
      | isHeading cur = True
      -- 리스트 시작은 문단 뒤일 때만 끊는다(연속 항목·중첩·헤딩 뒤는 그대로 둔다).
      | isListItem cur = not (isListItem prev) && not (isHeading prev)
      | otherwise = False

    blank :: Text -> Bool
    blank = T.null . T.strip

    -- 줄이 @*@ 한 개 이상으로 시작하고 그 뒤가 공백이면 헤딩으로 본다.
    isHeading :: Text -> Bool
    isHeading l = case T.uncons l of
      Just ('*', _) ->
        let s = T.dropWhile (== '*') l
         in T.null s || T.head s == ' '
      _ -> False

    -- 앞 공백을 무시하고 @-@/@+@/번호 뒤에 공백이 오면 리스트 항목으로 본다.
    isListItem :: Text -> Bool
    isListItem l = case T.uncons (T.dropWhile (== ' ') l) of
      Just ('-', r) -> spaceHead r
      Just ('+', r) -> spaceHead r
      Just (c, _)
        | isDigit c ->
            let r = T.dropWhile isDigit (T.dropWhile (== ' ') l)
             in case T.uncons r of
                  Just (d, r2) | d == '.' || d == ')' -> spaceHead r2
                  _                                   -> False
      _ -> False
      where
        spaceHead r = case T.uncons r of
          Just (' ', _) -> True
          _             -> False

    -- 문서를 @#+begin_src@ 같은 블록 지시자로 "시작"하면, 라이브러리의 meta
    -- 파서가 그 @#+@ 를 메타데이터 키(@#+KEY: VALUE@)로 오인해 삼키다 실패하고,
    -- 실패가 소비된 입력째로 번져 문서 전체 파싱이 무너진다(그 결과 'renderOrg'
    -- 가 원문 텍스트로 폴백해 @#+begin_src@ 가 글자 그대로 노출된다).
    --
    -- meta 의 키 스캔이 그 지시자 "앞"에서 끝나도록 보강한다. (1) 앞에 진짜
    -- 메타데이터가 있으면 그 뒤·지시자 앞에 빈 줄을 끼워 스캔을 끊는다. (2)
    -- 지시자가 맨 앞이라 끊어줄 메타가 없으면, 버려질 더미 메타 한 줄을 앞세운다.
    -- 더미 메타는 'renderOrg' 가 무시하는 메타데이터 맵으로만 들어가 출력에 드러나지
    -- 않으며, 뒤이은 빈 줄이 스캔을 끝내 지시자는 본문 블록 파서가 처리한다.
    fixLeadingBlock :: [Text] -> [Text]
    fixLeadingBlock ls =
      let (leadBlanks, rest0) = span blank ls
          (metaRun, rest1) = span isMetaLine rest0
       in case rest1 of
            (d : _)
              | isDirective d ->
                  if null metaRun
                    then leadBlanks <> ("#+blog_meta_guard: 1" : "" : rest1)
                    else leadBlanks <> metaRun <> ("" : rest1)
            _ -> ls
      where
        -- meta 가 키로 삼키지만 정상 메타가 아닌 @#+@ 줄(@#+begin_src@ 등).
        isDirective l =
          let s = T.dropWhile (== ' ') l
           in "#+" `T.isPrefixOf` s && not (isMetaLine s)

    -- 라이브러리의 @keyword@ 와 같은 판정: @#+@ + 키(@:@ 전까지) + @": "@ + 값(1자+).
    isMetaLine :: Text -> Bool
    isMetaLine l = case T.stripPrefix "#+" l of
      Nothing -> False
      Just rest ->
        let (key, afterKey) = T.break (== ':') rest
         in not (T.null key) && case T.stripPrefix ": " afterKey of
              Just val -> not (T.null val)
              Nothing  -> False
