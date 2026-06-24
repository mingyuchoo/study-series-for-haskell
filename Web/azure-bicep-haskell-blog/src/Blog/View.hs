-- | blaze-html을 사용한 HTML 뷰.
module Blog.View
  ( Viewer
  , ViewerInfo (..)
  , renderIndex
  , renderPost
  , renderNewForm
  , renderPreview
  , renderEditForm
  , renderNotFound
  , renderForbidden
  , renderSignup
  , renderVerify
  , renderLogin
  , renderProfile
  ) where

import Data.Text (Text)
import Data.Text qualified as T
import Data.Time (UTCTime, defaultTimeLocale, formatTime)
import Text.Blaze.Html (preEscapedToHtml)
import Text.Blaze.Html5 (Html, (!))
import Text.Blaze.Html5 qualified as H
import Text.Blaze.Html5.Attributes qualified as A
import Text.Blaze.Internal (customAttribute)

import Blog.Org (renderOrg)
import Blog.Post (Post (..), PostView (..))
import Blog.Publish (PostTarget (..), Token (..))
import Blog.Routes qualified as R
import Blog.User (Theme (..), User (..), renderTheme)
import Blog.View.Assets
  ( authCss
  , orgEditorScript
  , pageCss
  , themeInitScript
  , themeToggleScript
  )

-- | 로그인한 사용자 정보(비로그인은 'Nothing'). 헤더 표시·소유권 판정·테마 적용에 쓰인다.
data ViewerInfo = ViewerInfo
  { viewerUserId :: Int
  , viewerName   :: Text
  , viewerTheme  :: Theme
  }

type Viewer = Maybe ViewerInfo

-- | 현재 사용자가 글의 작성자인지(수정/삭제 권한 판정).
isOwner :: Viewer -> PostView -> Bool
isOwner (Just vi) pv = viewerUserId vi == postAuthorId (pvPost pv)
isOwner Nothing _    = False

-- | 작성자 이름을 공개 프로필 링크로 렌더한다.
authorLink :: PostView -> Html
authorLink (PostView p authorName) =
  H.a ! A.href (R.userPath (postAuthorId p)) $
    H.toHtml authorName

-- | 공통 레이아웃. 헤더에 로그인 상태(사용자/로그아웃 또는 로그인/회원가입)를 보인다.
--
-- 로그인 사용자는 계정에 저장된 테마를 @\<html data-theme=…\>@ 로 서버에서 직접
-- 적용해 첫 페인트부터 올바른 테마가 되게 한다(비로그인은 'themeInitScript' 가
-- localStorage 로 처리).
layout :: Viewer -> Text -> Html -> Html
layout viewer pageTitle inner = htmlRoot $ do
  H.head $ do
    H.meta ! A.charset "utf-8"
    H.meta ! A.name "viewport" ! A.content "width=device-width, initial-scale=1"
    H.title (H.toHtml pageTitle)
    -- 화면 깜빡임(FOUC) 방지를 위해 본문 렌더 전에 테마를 먼저 적용한다.
    H.script (preEscapedToHtml themeInitScript)
    H.style (H.toHtml pageCss)
    H.style (H.toHtml authCss)
  H.body $ do
    H.div ! A.class_ "container" $ do
      H.header $ do
        H.a ! A.href R.home ! A.class_ "brand" $ "Haskell Blog"
        H.div ! A.class_ "header-actions" $ do
          authNav viewer
          themeToggle viewer
      H.main inner
    H.script (preEscapedToHtml themeToggleScript)
    H.script ! A.type_ "module" $ preEscapedToHtml orgEditorScript
  where
    htmlRoot = case viewer of
      Just vi ->
        H.docTypeHtml
          ! A.lang "ko"
          ! customAttribute "data-theme" (H.toValue (renderTheme (viewerTheme vi)))
      Nothing -> H.docTypeHtml ! A.lang "ko"

-- | 헤더 우상단의 인증 네비게이션.
authNav :: Viewer -> Html
authNav (Just vi) =
  H.div ! A.class_ "auth-nav" $ do
    H.a ! A.href R.profile ! A.class_ "viewer" $ H.toHtml (viewerName vi)
    H.form ! A.method "post" ! A.action R.logout $
      H.button ! A.type_ "submit" ! A.class_ "btn btn-link" $
        "로그아웃"
authNav Nothing =
  H.div ! A.class_ "auth-nav" $ do
    H.a ! A.href R.login ! A.class_ "btn btn-link" $ "로그인"
    H.a ! A.href R.signup ! A.class_ "btn" $ "회원가입"

-- | 라이트↔다크 테마 토글 버튼(단일). 헤더 우상단에 배치된다.
--
-- 클릭하면 두 테마를 오간다. 아이콘·레이블·상태 갱신은 테마 스크립트
-- ('themeToggleScript')가 담당한다(라이트 레이블은 JS 미로딩 시의 폴백).
-- 로그인 상태면 @data-auth=\"1\"@ 를 달아, 토글 시 스크립트가 계정에도 저장한다.
themeToggle :: Viewer -> Html
themeToggle viewer = tag "라이트"
  where
    tag = case viewer of
      Just _  -> btn ! customAttribute "data-auth" "1"
      Nothing -> btn
    btn =
      H.button
        ! A.type_ "button"
        ! A.id "theme-toggle"
        ! A.class_ "btn theme-toggle"
        ! customAttribute "aria-label" "테마 전환"

-- | 글 목록 페이지.
renderIndex :: Viewer -> [PostView] -> Html
renderIndex viewer posts = layout viewer "Haskell Blog" $ do
  -- "새 글 작성"은 로그인 상태에서만 보인다(비로그인은 작성 라우트가 어차피
  -- /login 으로 리다이렉트되므로, 버튼을 숨겨 혼란을 줄인다).
  case viewer of
    Just _ ->
      H.div ! A.class_ "toolbar" $
        H.a ! A.href R.postsNew ! A.class_ "btn btn-primary" $
          "새 글 작성"
    Nothing -> mempty
  if null posts
    then H.p ! A.class_ "muted" $ "아직 작성된 글이 없습니다."
    else H.ul ! A.class_ "posts" $ mapM_ postItem posts
  where
    postItem :: PostView -> Html
    postItem pv@(PostView p _) = H.li $ do
      H.a ! A.href (R.postPath (postId p)) $
        H.toHtml (postTitle p)
      H.span ! A.class_ "meta" $ do
        H.toHtml (" · " :: Text)
        authorLink pv
        H.toHtml (" · " <> formatCreated (postCreatedAt p))

-- | 단일 글 페이지. 수정/삭제 버튼은 작성자 본인에게만 보인다.
renderPost :: Viewer -> PostView -> Html
renderPost viewer pv@(PostView p _) = layout viewer (postTitle p) $ do
  H.article $ do
    H.h2 (H.toHtml (postTitle p))
    H.p ! A.class_ "meta" $ do
      authorLink pv
      H.toHtml (" · " <> formatCreated (postCreatedAt p))
    H.div ! A.class_ "body" $ renderOrg (postBody p)
  if isOwner viewer pv
    then H.div ! A.class_ "actions" $ do
      H.a
        ! A.href (R.postEditPath (postId p))
        ! A.class_ "btn"
        $ "수정"
      H.form
        ! A.method "post"
        ! A.action (R.postDeletePath (postId p))
        ! A.onsubmit "return confirm('정말 삭제하시겠습니까?')"
        $ H.button ! A.type_ "submit" ! A.class_ "btn btn-danger"
        $ "삭제"
    else mempty
  H.p $ H.a ! A.href R.home ! A.class_ "backlink" $ "← 목록으로"

-- | 새 글 작성 폼.
--
-- 제목/내용 기본값을 받아 미리보기에서 \"수정\"으로 돌아올 때 입력값을 보존한다.
-- 제출 시 바로 발행하지 않고 \"/posts/preview\"로 보내 미리보기를 거친다.
renderNewForm :: Viewer -> Text -> Text -> Html
renderNewForm viewer titleVal bodyVal = layout viewer "새 글 작성" $ do
  H.h2 "새 글 작성"
  H.form ! A.method "post" ! A.action R.postsPreview $ do
    H.div ! A.class_ "field" $ do
      H.label ! A.for "title" $ "제목"
      H.input
        ! A.type_ "text"
        ! A.name "title"
        ! A.id "title"
        ! A.required "required"
        ! A.value (H.toValue titleVal)
    orgEditorField bodyVal
    H.div ! A.class_ "actions" $ do
      H.button ! A.type_ "submit" ! A.class_ "btn btn-primary" $ "미리보기"
      H.a ! A.href R.home ! A.class_ "btn" $ "취소"

-- | 발행 전 미리보기 페이지.
--
-- 입력값을 실제 글처럼 렌더링해 보여주고, \"발행\"으로 저장하거나
-- \"수정\"으로 입력값을 유지한 채 작성/수정 폼으로 돌아갈 수 있다.
--
-- 발행 폼에는 서버가 발급한 서명 토큰을 함께 실어 보낸다. 발행 라우트는 이
-- 토큰을 검증해야만 글을 저장하므로, 미리보기를 건너뛴 발행/수정이 차단된다.
--
-- 'PostTarget' 에 따라 발행/수정 폼의 전송 경로가 달라진다(새 글 vs 기존 글).
renderPreview :: Viewer -> PostTarget -> Text -> Text -> Token -> Html
renderPreview viewer target titleVal bodyVal tok = layout viewer "미리보기" $ do
  H.p ! A.class_ "muted" $ "미리보기 — 아직 저장되지 않았습니다."
  H.article $ do
    H.h2 (H.toHtml titleVal)
    H.div ! A.class_ "body" $ renderOrg bodyVal
  H.div ! A.class_ "actions" $ do
    H.form ! A.method "post" ! A.action publishAction $ do
      draftFields
      H.input ! A.type_ "hidden" ! A.name "token" ! A.value (H.toValue (unToken tok))
      H.button ! A.type_ "submit" ! A.class_ "btn btn-primary" $ "발행"
    H.form ! A.method "post" ! A.action reviseAction $ do
      draftFields
      H.button ! A.type_ "submit" ! A.class_ "btn" $ "수정"
  where
    -- 발행은 새 글이면 insert(/posts), 기존 글이면 update(/posts/:id/edit).
    -- "수정"은 입력값을 유지한 채 해당 작성/수정 폼으로 되돌린다.
    (publishAction, reviseAction) = case target of
      NewTarget      -> (R.postsCollection, R.postsDraft)
      EditTarget pid -> (R.postEditPath pid, R.postDraftPath pid)

    draftFields :: Html
    draftFields = do
      H.input ! A.type_ "hidden" ! A.name "title" ! A.value (H.toValue titleVal)
      H.input ! A.type_ "hidden" ! A.name "body" ! A.value (H.toValue bodyVal)

-- | 글 수정 폼. 기존(또는 되돌아온) 값을 미리 채운다.
--
-- 제출 시 바로 저장하지 않고 \"/posts/:id/preview\"로 보내 미리보기를 거친다.
renderEditForm :: Viewer -> Int -> Text -> Text -> Html
renderEditForm viewer pid titleVal bodyVal = layout viewer "글 수정" $ do
  H.h2 "글 수정"
  H.form
    ! A.method "post"
    ! A.action (R.postPreviewPath pid)
    $ do
      H.div ! A.class_ "field" $ do
        H.label ! A.for "title" $ "제목"
        H.input
          ! A.type_ "text"
          ! A.name "title"
          ! A.id "title"
          ! A.required "required"
          ! A.value (H.toValue titleVal)
      orgEditorField bodyVal
      H.div ! A.class_ "actions" $ do
        H.button ! A.type_ "submit" ! A.class_ "btn btn-primary" $ "미리보기"
        H.a
          ! A.href (R.postPath pid)
          ! A.class_ "btn"
          $ "취소"

-- | 404 페이지.
renderNotFound :: Viewer -> Html
renderNotFound viewer = layout viewer "찾을 수 없음" $ do
  H.h2 "404"
  H.p ! A.class_ "muted" $ "요청한 글을 찾을 수 없습니다."
  H.p $ H.a ! A.href R.home ! A.class_ "backlink" $ "← 목록으로"

-- | 403 페이지(타인 글 수정/삭제 시도).
renderForbidden :: Viewer -> Html
renderForbidden viewer = layout viewer "권한 없음" $ do
  H.h2 "403"
  H.p ! A.class_ "muted" $ "이 글에 대한 권한이 없습니다. 작성자만 수정·삭제할 수 있습니다."
  H.p $ H.a ! A.href R.home ! A.class_ "backlink" $ "← 목록으로"

-- | 프로필 페이지. 사용자 정보·소개와 작성한 글 목록을 보여준다.
--
-- @editable@ 이 참이면(본인 프로필) 이름·소개·비밀번호·테마 설정을 함께 띄운다.
-- @mErr@ 가 있으면(주로 비밀번호 변경 실패) 설정 상단에 오류를 보여준다.
renderProfile :: Viewer -> User -> [PostView] -> Bool -> Maybe Text -> Html
renderProfile viewer user posts editable mErr = layout viewer (userName user) $ do
  H.section ! A.class_ "profile" $ do
    H.h2 (H.toHtml (userName user))
    H.p ! A.class_ "meta" $ H.toHtml ("가입: " <> formatCreated (userCreatedAt user))
    if T.null (T.strip (userBio user))
      then H.p ! A.class_ "muted" $ "소개가 없습니다."
      else H.p ! A.class_ "bio" $ H.toHtml (userBio user)
    if editable
      then do
        errorNote mErr
        profileEditForm user
        passwordForm
        themeForm (userTheme user)
      else mempty
  H.h3 "작성한 글"
  if null posts
    then H.p ! A.class_ "muted" $ "아직 작성한 글이 없습니다."
    else H.ul ! A.class_ "posts" $ mapM_ postLink posts
  H.p $ H.a ! A.href R.home ! A.class_ "backlink" $ "← 목록으로"
  where
    postLink (PostView p _) = H.li $ do
      H.a ! A.href (R.postPath (postId p)) $
        H.toHtml (postTitle p)
      H.span ! A.class_ "meta" $ H.toHtml (" · " <> formatCreated (postCreatedAt p))

-- | 본인 프로필의 이름·소개 수정 폼.
profileEditForm :: User -> Html
profileEditForm user =
  H.form ! A.method "post" ! A.action R.profile ! A.class_ "profile-edit" $ do
    H.div ! A.class_ "field" $ do
      H.label ! A.for "name" $ "표시 이름"
      H.input
        ! A.type_ "text"
        ! A.name "name"
        ! A.id "name"
        ! A.required "required"
        ! A.value (H.toValue (userName user))
    H.div ! A.class_ "field" $ do
      H.label ! A.for "bio" $ "소개"
      H.textarea ! A.name "bio" ! A.id "bio" ! A.rows "4" $ H.toHtml (userBio user)
    H.div ! A.class_ "actions" $
      H.button ! A.type_ "submit" ! A.class_ "btn btn-primary" $
        "프로필 저장"

-- | 비밀번호 변경 폼. 현재 비밀번호로 본인 확인 후 새 비밀번호로 바꾼다.
--   값은 절대 미리 채우지 않으며, autocomplete 힌트로 매니저 연동을 돕는다.
passwordForm :: Html
passwordForm =
  H.form ! A.method "post" ! A.action R.profilePassword ! A.class_ "profile-edit" $ do
    H.h3 "비밀번호 변경"
    H.div ! A.class_ "field" $ do
      H.label ! A.for "current" $ "현재 비밀번호"
      H.input
        ! A.type_ "password"
        ! A.name "current"
        ! A.id "current"
        ! A.required "required"
        ! A.autocomplete "current-password"
    H.div ! A.class_ "field" $ do
      H.label ! A.for "new" $ "새 비밀번호 (8자 이상)"
      H.input
        ! A.type_ "password"
        ! A.name "new"
        ! A.id "new"
        ! A.required "required"
        ! customAttribute "minlength" "8"
        ! A.autocomplete "new-password"
    H.div ! A.class_ "field" $ do
      H.label ! A.for "confirm" $ "새 비밀번호 확인"
      H.input
        ! A.type_ "password"
        ! A.name "confirm"
        ! A.id "confirm"
        ! A.required "required"
        ! customAttribute "minlength" "8"
        ! A.autocomplete "new-password"
    H.div ! A.class_ "actions" $
      H.button ! A.type_ "submit" ! A.class_ "btn btn-primary" $
        "비밀번호 변경"

-- | 계정 테마 설정 폼. 라이트/다크를 계정에 저장한다(헤더 토글과 같은 저장 경로).
themeForm :: Theme -> Html
themeForm current =
  H.form ! A.method "post" ! A.action R.profileTheme ! A.class_ "profile-edit" $ do
    H.h3 "테마"
    H.p ! A.class_ "hint" $ "계정에 저장 — 어느 기기에서 로그인해도 이 테마로 시작합니다."
    H.div ! A.class_ "field" $ do
      themeRadio "light" "라이트" (current == Light)
      themeRadio "dark" "다크" (current == Dark)
    H.div ! A.class_ "actions" $
      H.button ! A.type_ "submit" ! A.class_ "btn btn-primary" $
        "테마 저장"
  where
    themeRadio :: H.AttributeValue -> Text -> Bool -> Html
    themeRadio val label checked =
      H.label ! A.class_ "theme-option" $ do
        let radio = H.input ! A.type_ "radio" ! A.name "theme" ! A.value val
        if checked then radio ! A.checked "checked" else radio
        H.toHtml label

-- | 회원가입 폼. @mErr@ 가 있으면 오류 메시지를 띄운다.
renderSignup :: Viewer -> Maybe Text -> Html
renderSignup viewer mErr = layout viewer "회원가입" $ do
  H.h2 "회원가입"
  errorNote mErr
  H.form ! A.method "post" ! A.action R.signup $ do
    H.div ! A.class_ "field" $ do
      H.label ! A.for "email" $ "이메일"
      H.input ! A.type_ "email" ! A.name "email" ! A.id "email" ! A.required "required"
    H.div ! A.class_ "field" $ do
      H.label ! A.for "name" $ "표시 이름"
      H.input ! A.type_ "text" ! A.name "name" ! A.id "name" ! A.required "required"
    H.div ! A.class_ "field" $ do
      H.label ! A.for "password" $ "비밀번호 (8자 이상)"
      H.input
        ! A.type_ "password"
        ! A.name "password"
        ! A.id "password"
        ! A.required "required"
        ! customAttribute "minlength" "8"
    H.div ! A.class_ "actions" $ do
      H.button ! A.type_ "submit" ! A.class_ "btn btn-primary" $ "가입"
      H.a ! A.href R.login ! A.class_ "btn btn-link" $ "이미 계정이 있나요? 로그인"

-- | 이메일 인증 코드 입력 페이지(회원가입 2단계). @mErr@ 가 있으면 오류를 보인다.
--   숨은 email 필드로 어떤 가입을 검증할지 전달하고, 코드 입력 + 재전송을 제공한다.
renderVerify :: Text -> Maybe Text -> Html
renderVerify email mErr = layout Nothing "이메일 인증" $ do
  H.h2 "이메일 인증"
  errorNote mErr
  H.p ! A.class_ "muted" $ H.toHtml (email <> " 으로 6자리 인증 코드를 보냈습니다. (10분 내 입력)")
  H.form ! A.method "post" ! A.action R.signupVerify $ do
    H.input ! A.type_ "hidden" ! A.name "email" ! A.value (H.toValue email)
    H.div ! A.class_ "field" $ do
      H.label ! A.for "code" $ "인증 코드"
      H.input
        ! A.type_ "text"
        ! A.name "code"
        ! A.id "code"
        ! A.required "required"
        ! A.autocomplete "one-time-code"
        ! customAttribute "inputmode" "numeric"
        ! customAttribute "pattern" "[0-9]{6}"
        ! customAttribute "maxlength" "6"
    H.div ! A.class_ "actions" $
      H.button ! A.type_ "submit" ! A.class_ "btn btn-primary" $
        "인증하고 가입 완료"
  H.form ! A.method "post" ! A.action R.signupResend $ do
    H.input ! A.type_ "hidden" ! A.name "email" ! A.value (H.toValue email)
    H.button ! A.type_ "submit" ! A.class_ "btn btn-link" $ "코드 다시 보내기"

-- | 로그인 폼. @mErr@ 가 있으면 오류 메시지를 띄운다.
renderLogin :: Viewer -> Maybe Text -> Html
renderLogin viewer mErr = layout viewer "로그인" $ do
  H.h2 "로그인"
  errorNote mErr
  H.form ! A.method "post" ! A.action R.login $ do
    H.div ! A.class_ "field" $ do
      H.label ! A.for "email" $ "이메일"
      H.input ! A.type_ "email" ! A.name "email" ! A.id "email" ! A.required "required"
    H.div ! A.class_ "field" $ do
      H.label ! A.for "password" $ "비밀번호"
      H.input ! A.type_ "password" ! A.name "password" ! A.id "password" ! A.required "required"
    H.div ! A.class_ "actions" $ do
      H.button ! A.type_ "submit" ! A.class_ "btn btn-primary" $ "로그인"
      H.a ! A.href R.signup ! A.class_ "btn btn-link" $ "회원가입"

-- | 인증 폼 상단의 오류 알림(없으면 아무것도 렌더하지 않음).
errorNote :: Maybe Text -> Html
errorNote Nothing    = mempty
errorNote (Just msg) = H.p ! A.class_ "form-error" $ H.toHtml msg

formatCreated :: UTCTime -> Text
formatCreated = T.pack . formatTime defaultTimeLocale "%Y-%m-%d %H:%M"

-- | 작성/수정 폼에 표시하는 Org 문법 안내.
orgHint :: Html
orgHint =
  H.p ! A.class_ "hint" $
    "Org 문법을 사용할 수 있습니다 — 제목 *, 굵게 *텍스트*, 기울임 /텍스트/, 코드 ~텍스트~, 목록 -, 링크 [[URL][설명]], 소스 #+begin_src ... #+end_src"

-- | Org 본문 입력 영역 — 좌측 CodeMirror 라이브 에디터 + 우측 서버 렌더 미리보기.
--
-- textarea#body 는 폼 전송 필드이자 점진적 향상의 기반이다. 'orgEditorScript'
-- 가 로드되면 이 textarea 를 CM 에디터로 승격하고 숨긴다. JS 미로딩/실패 시에는
-- textarea 가 그대로 보여 평범하게 동작한다.
orgEditorField :: Text -> Html
orgEditorField bodyVal = H.div ! A.class_ "field" $ do
  H.label ! A.for "body" $ "내용"
  H.div ! A.class_ "org-split" $ do
    H.div ! A.class_ "org-pane" $ do
      H.div ! A.class_ "pane-label" $ "편집 · org-bullets"
      H.textarea ! A.name "body" ! A.id "body" ! A.rows "16" ! A.required "required" $
        H.toHtml bodyVal
      H.div ! A.id "org-editor" $ mempty
    H.div ! A.class_ "org-pane" $ do
      H.div ! A.class_ "pane-label" $ "미리보기"
      H.div ! A.id "org-preview" ! A.class_ "body" $ mempty
  orgHint
