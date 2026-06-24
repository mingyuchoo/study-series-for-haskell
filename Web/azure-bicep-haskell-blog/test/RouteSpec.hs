-- | 라우트 테스트.
--
-- 'PostStore'/'UserStore' 추상 덕분에 PostgreSQL 없이 인메모리 구현을 주입해
-- 'Blog.App'의 라우트를 그대로 검증한다. wai-test 'Session' 은 응답의 Set-Cookie
-- 를 쿠키 항아리에 담아 이후 요청에 자동으로 실어 보내므로, 회원가입/로그인
-- 한 번이면 같은 세션의 다음 요청들은 인증된 상태가 된다.
module RouteSpec
  ( routeTests
  ) where

import Control.Monad.IO.Class (liftIO)
import Data.ByteString (ByteString)
import Data.ByteString.Char8 qualified as BS8
import Data.ByteString.Lazy qualified as LBS
import Data.IORef
  ( IORef
  , atomicModifyIORef'
  , modifyIORef'
  , newIORef
  , readIORef
  , writeIORef
  )
import Data.List (find, sortOn)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Ord (Down (..))
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Encoding qualified as TE
import Data.Time (UTCTime (..), fromGregorian, secondsToDiffTime)
import Network.HTTP.Types.Header (hContentType, hLocation)
import Network.Wai (Application, Request (..), defaultRequest)
import Network.Wai.Test
  ( SRequest (..)
  , SResponse (..)
  , Session
  , assertBody
  , assertBodyContains
  , assertHeader
  , assertStatus
  , request
  , runSession
  , setPath
  , srequest
  )
import Test.HUnit (Test (..), assertBool)
import Web.Scotty (scottyApp)

import Blog.App (Env (..), application)
import Blog.Email (Code (..), EmailSender (..))
import Blog.Keys (deriveKeys)
import Blog.Post (NewPost (..), Post (..), PostStore (..), PostView (..))
import Blog.User (NewUser (..), Theme (..), User (..), UserError (..), UserStore (..))
import Blog.Verification (PendingSignup (..), VerificationStore (..))

-- | 'IORef' 기반 인메모리 'PostStore'. 작성자 이름은 'UserStore' 로 해소한다
--   (PostgreSQL 구현이 users JOIN 으로 채우는 것과 같은 역할).
newInMemoryStore :: UserStore -> IO PostStore
newInMemoryStore ustore = do
  ref <- newIORef (Map.empty :: Map Int Post)
  counter <- newIORef (0 :: Int)
  let fixedTime = UTCTime (fromGregorian 2026 6 20) (secondsToDiffTime 0)
      -- 저장 행에 작성자 이름을 붙여 읽기 모델로 만든다(DB 구현의 users JOIN 역할).
      toView :: Post -> IO PostView
      toView p = do
        name <- maybe "" userName <$> userById ustore (postAuthorId p)
        pure (PostView p name)
  pure
    PostStore
      { storeList =
          readIORef ref >>= traverse toView . sortOn (Down . postId) . Map.elems
      , storeListByAuthor = \authorId ->
          readIORef ref
            >>= traverse toView
              . sortOn (Down . postId)
              . filter ((== authorId) . postAuthorId)
              . Map.elems
      , storeGet = \pid ->
          readIORef ref >>= traverse toView . Map.lookup pid
      , storeInsert = \authorId (NewPost title body) -> do
          pid <- atomicModifyIORef' counter (\n -> (n + 1, n + 1))
          let p = Post pid title body fixedTime authorId
          modifyIORef' ref (Map.insert pid p)
          pure p
      , storeUpdate = \pid (NewPost title body) -> do
          m <- readIORef ref
          case Map.lookup pid m of
            Nothing -> pure Nothing
            Just old -> do
              let p = old {postTitle = title, postBody = body}
              modifyIORef' ref (Map.insert pid p)
              pure (Just p)
      , storeDelete = \pid -> do
          m <- readIORef ref
          if Map.member pid m
            then modifyIORef' ref (Map.delete pid) >> pure True
            else pure False
      }

-- | 'IORef' 기반 인메모리 'UserStore'. 비밀번호는 핸들러가 이미 해시한 값이다.
newInMemoryUserStore :: IO UserStore
newInMemoryUserStore = do
  ref <- newIORef (Map.empty :: Map Int User)
  counter <- newIORef (0 :: Int)
  let fixedTime = UTCTime (fromGregorian 2026 6 20) (secondsToDiffTime 0)
      modifyUser uid f = do
        m <- readIORef ref
        case Map.lookup uid m of
          Nothing -> pure Nothing
          Just u -> do
            let u' = f u
            modifyIORef' ref (Map.insert uid u')
            pure (Just u')
  pure
    UserStore
      { userInsert = \(NewUser email name hash) -> do
          m <- readIORef ref
          if any ((== email) . userEmail) (Map.elems m)
            then pure (Left EmailTaken)
            else do
              uid <- atomicModifyIORef' counter (\n -> (n + 1, n + 1))
              let u = User uid email name "" hash fixedTime Light
              modifyIORef' ref (Map.insert uid u)
              pure (Right u)
      , userByEmail = \email ->
          find ((== email) . userEmail) . Map.elems <$> readIORef ref
      , userById = \uid ->
          Map.lookup uid <$> readIORef ref
      , userUpdateProfile = \uid name bio ->
          modifyUser uid (\u -> u {userName = name, userBio = bio})
      , userUpdatePassword = \uid hash ->
          modifyUser uid (\u -> u {userPasswordHash = hash})
      , userUpdateTheme = \uid theme ->
          modifyUser uid (\u -> u {userTheme = theme})
      }

-- | 'IORef' 기반 인메모리 'VerificationStore'.
newInMemoryVerificationStore :: IO VerificationStore
newInMemoryVerificationStore = do
  ref <- newIORef (Map.empty :: Map Text PendingSignup)
  pure
    VerificationStore
      { storePending = \p -> modifyIORef' ref (Map.insert (pendingEmail p) p)
      , getPending = \email -> Map.lookup email <$> readIORef ref
      , bumpAttempts = \email ->
          modifyIORef' ref (Map.adjust (\p -> p {pendingAttempts = pendingAttempts p + 1}) email)
      , deletePending = \email -> modifyIORef' ref (Map.delete email)
      }

-- | 테스트용 서명키 (운영 키와 무관, 실행 간 고정).
testSecret :: ByteString
testSecret = "test-app-secret"

-- | 인메모리 저장소를 주입한 WAI 'Application'을 만든다 (테스트마다 격리).
--   가입 없이 쓰는 테스트용 — 발송 코드는 버린다.
mkApp :: IO Application
mkApp = fst <$> mkAppC

-- | 앱 + "최근 발송된 인증 코드" ref. 2단계 가입을 거치는 테스트에 쓴다.
--   가짜 'EmailSender' 가 실제 발송 대신 코드를 ref 에 담는다.
mkAppC :: IO (Application, IORef (Maybe Text))
mkAppC = do
  ustore <- newInMemoryUserStore
  store <- newInMemoryStore ustore
  vstore <- newInMemoryVerificationStore
  codeRef <- newIORef Nothing
  let sender = EmailSender (\_email (Code c) -> writeIORef codeRef (Just c))
      env =
        Env
          { envKeys = deriveKeys testSecret
          , envUsers = ustore
          , envPosts = store
          , envSender = sender
          , envVerify = vstore
          }
  app <- scottyApp (application env)
  pure (app, codeRef)

-- 요청 헬퍼 --------------------------------------------------------------

runGet :: ByteString -> Session SResponse
runGet path =
  request (setPath defaultRequest {requestMethod = "GET"} path)

runPostForm :: ByteString -> LBS.ByteString -> Session SResponse
runPostForm path body =
  srequest (SRequest req body)
  where
    req =
      setPath
        defaultRequest
          { requestMethod = "POST"
          , requestHeaders = [(hContentType, "application/x-www-form-urlencoded")]
          }
        path

-- 인증 헬퍼 --------------------------------------------------------------

-- | 기본 테스트 사용자 가입 폼.
defaultUser :: LBS.ByteString
defaultUser = "email=alice@example.com&name=Alice&password=secret12"

-- | 두 번째 테스트 사용자(소유권 테스트용).
secondUser :: LBS.ByteString
secondUser = "email=bob@example.com&name=Bob&password=secret12"

-- | 폼 본문에서 필드 값을 뽑는다(테스트 입력은 URL-인코딩 특수문자 없음).
formField :: ByteString -> LBS.ByteString -> Text
formField key form =
  let body = TE.decodeUtf8 (LBS.toStrict form)
      prefix = TE.decodeUtf8 key <> "="
      (_, after) = T.breakOn prefix body
   in T.takeWhile (/= '&') (T.drop (T.length prefix) after)

-- | 2단계 가입을 끝까지 수행한다: 코드 발송 요청 → 캡처된 코드로 인증.
--   인증에 성공하면 세션 쿠키가 항아리에 담겨 로그인 상태가 된다.
verifiedSignup :: IORef (Maybe Text) -> LBS.ByteString -> Session SResponse
verifiedSignup codeRef form = do
  _ <- runPostForm "/signup" form
  code <- maybe "" id <$> liftIO (readIORef codeRef)
  let email = formField "email" form
  runPostForm
    "/signup/verify"
    (LBS.fromStrict (TE.encodeUtf8 ("email=" <> email <> "&code=" <> code)))

-- | 기본 사용자로 가입·인증을 마친 뒤 본문을 실행한다.
withUser :: IORef (Maybe Text) -> Session a -> Session a
withUser codeRef body = verifiedSignup codeRef defaultUser >> body

-- 토큰/미리보기 헬퍼 -----------------------------------------------------

-- | 응답 본문을 UTF-8 텍스트로 디코딩한다.
decodeBody :: SResponse -> Text
decodeBody = TE.decodeUtf8 . LBS.toStrict . simpleBody

-- | 본문에 'Text' 가 포함되어 있는지 검사한다(한글 등 UTF-8 안전 — ByteString
--   리터럴 기반 'assertBodyContains' 는 Char8 로 깨지므로 디코딩 후 비교한다).
assertBodyHas :: Text -> SResponse -> Session ()
assertBodyHas needle r =
  liftIO
    ( assertBool
        ("본문에 있어야 할 문자열: " <> T.unpack needle)
        (needle `T.isInfixOf` decodeBody r)
    )

-- | 본문에 'Text' 가 없는지 검사한다.
assertBodyExcludes :: Text -> SResponse -> Session ()
assertBodyExcludes needle r =
  liftIO
    ( assertBool
        ("본문에 없어야 할 문자열: " <> T.unpack needle)
        (not (needle `T.isInfixOf` decodeBody r))
    )

-- | 미리보기 응답 HTML에서 발행 폼의 서명 토큰(hidden input)을 뽑아낸다.
extractToken :: SResponse -> Text
extractToken r =
  let body = decodeBody r
      marker = "name=\"token\" value=\""
      (_, afterMarker) = T.breakOn marker body
      after = T.drop (T.length marker) afterMarker
   in T.takeWhile (/= '"') after

-- | 미리보기 경로로 토큰을 받은 뒤, 그 토큰을 실어 발행 경로로 제출한다.
previewThenSubmit :: ByteString -> ByteString -> LBS.ByteString -> Session SResponse
previewThenSubmit previewPath submitPath form = do
  prev <- runPostForm previewPath form
  let tok = extractToken prev
  runPostForm submitPath (form <> "&token=" <> LBS.fromStrict (TE.encodeUtf8 tok))

-- | 정상 흐름(미리보기 → 토큰 → 발행)으로 새 글을 발행한다.
publishViaPreview :: LBS.ByteString -> Session SResponse
publishViaPreview = previewThenSubmit "/posts/preview" "/posts"

-- | 정상 흐름(미리보기 → 토큰 → 발행)으로 기존 글(id)을 수정한다.
updateViaPreview :: Int -> LBS.ByteString -> Session SResponse
updateViaPreview pid =
  previewThenSubmit (editPath "preview") (editPath "edit")
  where
    editPath seg = BS8.pack ("/posts/" ++ show pid ++ "/" ++ seg)

-- 공개 라우트 ------------------------------------------------------------

-- 헬스 프로브는 항상 200/ok.
testHealth :: Test
testHealth = TestCase $ do
  app <- mkApp
  flip runSession app $ do
    r <- runGet "/health"
    assertStatus 200 r
    assertBody "ok" r

-- 빈 목록 페이지는 200.
testEmptyIndex :: Test
testEmptyIndex = TestCase $ do
  app <- mkApp
  flip runSession app $ do
    r <- runGet "/"
    assertStatus 200 r

-- 비로그인 목록에는 "새 글 작성" 버튼이 없다.
testNewButtonHiddenAnon :: Test
testNewButtonHiddenAnon = TestCase $ do
  app <- mkApp
  flip runSession app $ do
    r <- runGet "/"
    assertStatus 200 r
    assertBodyExcludes "새 글 작성" r

-- 로그인 목록에는 "새 글 작성" 버튼이 있다.
testNewButtonShownAuth :: Test
testNewButtonShownAuth = TestCase $ do
  (app, codeRef) <- mkAppC
  flip runSession app $ withUser codeRef $ do
    r <- runGet "/"
    assertStatus 200 r
    assertBodyHas "새 글 작성" r

-- 없는 글은 404.
testNotFound :: Test
testNotFound = TestCase $ do
  app <- mkApp
  flip runSession app $ do
    r <- runGet "/posts/999"
    assertStatus 404 r

-- 인증 ------------------------------------------------------------------

-- 비로그인 상태로 보호된 라우트에 접근하면 /login 으로 리다이렉트된다.
testProtectedRedirectsAnon :: Test
testProtectedRedirectsAnon = TestCase $ do
  app <- mkApp
  flip runSession app $ do
    r <- runGet "/posts/new"
    assertStatus 302 r
    assertHeader hLocation "/login" r

-- 회원가입은 세션을 만들고, 같은 세션에서 보호된 폼에 접근할 수 있다.
testSignupCreatesSession :: Test
testSignupCreatesSession = TestCase $ do
  (app, codeRef) <- mkAppC
  flip runSession app $ withUser codeRef $ do
    r <- runGet "/posts/new"
    assertStatus 200 r
    assertBodyContains "<form" r

-- 코드 발송 요청만으로는 계정·세션이 생기지 않는다(인증 필수).
testSignupRequiresVerification :: Test
testSignupRequiresVerification = TestCase $ do
  (app, _) <- mkAppC
  flip runSession app $ do
    s <- runPostForm "/signup" defaultUser
    assertStatus 200 s -- 코드 입력 페이지(아직 미가입)
    r <- runGet "/posts/new"
    assertStatus 302 r -- 여전히 비로그인
    assertHeader hLocation "/login" r

-- 잘못된 코드로는 인증되지 않고, 계정도 생기지 않는다.
testSignupWrongCode :: Test
testSignupWrongCode = TestCase $ do
  (app, codeRef) <- mkAppC
  flip runSession app $ do
    _ <- runPostForm "/signup" defaultUser
    real <- maybe "" id <$> liftIO (readIORef codeRef)
    let wrong = if real == "000000" then "111111" else "000000"
    v <-
      runPostForm
        "/signup/verify"
        (LBS.fromStrict (TE.encodeUtf8 ("email=alice@example.com&code=" <> wrong)))
    assertStatus 400 v
    r <- runGet "/posts/new"
    assertStatus 302 r -- 여전히 비로그인

-- 이미 가입된 이메일로 다시 가입 요청하면 거부된다.
testSignupDuplicateEmail :: Test
testSignupDuplicateEmail = TestCase $ do
  (app, codeRef) <- mkAppC
  flip runSession app $ do
    _ <- verifiedSignup codeRef defaultUser
    r <- runPostForm "/signup" defaultUser
    assertStatus 400 r

-- 잘못된 비밀번호로는 로그인할 수 없다.
testLoginWrongPassword :: Test
testLoginWrongPassword = TestCase $ do
  (app, codeRef) <- mkAppC
  flip runSession app $ do
    _ <- verifiedSignup codeRef defaultUser
    r <- runPostForm "/login" "email=alice@example.com&password=wrongpass"
    assertStatus 400 r

-- 로그아웃하면 보호된 라우트가 다시 차단되고, 재로그인하면 다시 접근된다.
testLoginLogoutFlow :: Test
testLoginLogoutFlow = TestCase $ do
  (app, codeRef) <- mkAppC
  flip runSession app $ do
    _ <- verifiedSignup codeRef defaultUser
    -- 로그아웃 → 쿠키 만료 → 보호 라우트 차단.
    _ <- runPostForm "/logout" ""
    anon <- runGet "/posts/new"
    assertStatus 302 anon
    -- 재로그인 → 다시 접근 가능.
    loginResp <- runPostForm "/login" "email=alice@example.com&password=secret12"
    assertStatus 302 loginResp
    ok <- runGet "/posts/new"
    assertStatus 200 ok

-- 글 작성/수정/삭제 (로그인 필요) --------------------------------------

-- 미리보기 → 발행 정상 흐름 → 첫 글 id=1 로 리다이렉트, 이후 조회 시 제목이 보인다.
testCreateAndRead :: Test
testCreateAndRead = TestCase $ do
  (app, codeRef) <- mkAppC
  flip runSession app $ withUser codeRef $ do
    c <- publishViaPreview "title=Hello&body=World"
    assertStatus 302 c
    assertHeader hLocation "/posts/1" c
    r <- runGet "/posts/1"
    assertStatus 200 r
    assertBodyContains "Hello" r

-- 로그인했어도 토큰 없이 직접 POST /posts 발행은 거부되고, 저장되지 않는다.
testPublishWithoutTokenRejected :: Test
testPublishWithoutTokenRejected = TestCase $ do
  (app, codeRef) <- mkAppC
  flip runSession app $ withUser codeRef $ do
    c <- runPostForm "/posts" "title=Hello&body=World"
    assertStatus 400 c
    r <- runGet "/posts/1"
    assertStatus 404 r

-- 미리보기 후 내용을 변조하면(토큰 불일치) 발행이 거부된다.
testPublishTamperedRejected :: Test
testPublishTamperedRejected = TestCase $ do
  (app, codeRef) <- mkAppC
  flip runSession app $ withUser codeRef $ do
    prev <- runPostForm "/posts/preview" "title=Hello&body=World"
    let tok = extractToken prev
    c <-
      runPostForm
        "/posts"
        ("title=Hello&body=Tampered&token=" <> LBS.fromStrict (TE.encodeUtf8 tok))
    assertStatus 400 c
    r <- runGet "/posts/1"
    assertStatus 404 r

-- 미리보기는 저장하지 않고 200으로 입력 내용과 발행/수정 액션을 보여준다.
testPreview :: Test
testPreview = TestCase $ do
  (app, codeRef) <- mkAppC
  flip runSession app $ withUser codeRef $ do
    p <- runPostForm "/posts/preview" "title=Draft&body=Hello"
    assertStatus 200 p
    assertBodyContains "Draft" p
    assertBodyContains "Hello" p
    assertBodyContains "action=\"/posts\"" p
    assertBodyContains "action=\"/posts/draft\"" p
    r <- runGet "/posts/1"
    assertStatus 404 r

-- "수정"은 입력값을 유지한 채 작성 폼(200)으로 돌아간다.
testDraftBack :: Test
testDraftBack = TestCase $ do
  (app, codeRef) <- mkAppC
  flip runSession app $ withUser codeRef $ do
    d <- runPostForm "/posts/draft" "title=Keep&body=Me"
    assertStatus 200 d
    assertBodyContains "<form" d
    assertBodyContains "Keep" d
    assertBodyContains "Me" d

-- 수정도 미리보기 → 토큰 → 발행을 거쳐야 하고, 그 후 새 제목이 반영된다.
testUpdate :: Test
testUpdate = TestCase $ do
  (app, codeRef) <- mkAppC
  flip runSession app $ withUser codeRef $ do
    _ <- publishViaPreview "title=Old&body=B"
    u <- updateViaPreview 1 "title=New&body=B2"
    assertStatus 302 u
    assertHeader hLocation "/posts/1" u
    r <- runGet "/posts/1"
    assertBodyContains "New" r

-- 미리보기 토큰 없이 직접 수정 발행하면 거부되고, 기존 내용이 유지된다.
testUpdateWithoutTokenRejected :: Test
testUpdateWithoutTokenRejected = TestCase $ do
  (app, codeRef) <- mkAppC
  flip runSession app $ withUser codeRef $ do
    _ <- publishViaPreview "title=Old&body=B"
    u <- runPostForm "/posts/1/edit" "title=New&body=B2"
    assertStatus 400 u
    r <- runGet "/posts/1"
    assertBodyContains "Old" r

-- 새 글용 토큰을 다른 글 수정에 재사용할 수 없다(대상이 토큰에 묶임).
testCrossTargetTokenRejected :: Test
testCrossTargetTokenRejected = TestCase $ do
  (app, codeRef) <- mkAppC
  flip runSession app $ withUser codeRef $ do
    _ <- publishViaPreview "title=Old&body=B"
    prev <- runPostForm "/posts/preview" "title=New&body=B2"
    let tok = extractToken prev
    u <-
      runPostForm
        "/posts/1/edit"
        ("title=New&body=B2&token=" <> LBS.fromStrict (TE.encodeUtf8 tok))
    assertStatus 400 u
    r <- runGet "/posts/1"
    assertBodyContains "Old" r

-- 삭제 후 목록(/)으로 리다이렉트하고, 이후 조회는 404.
testDelete :: Test
testDelete = TestCase $ do
  (app, codeRef) <- mkAppC
  flip runSession app $ withUser codeRef $ do
    _ <- publishViaPreview "title=Doomed&body=B"
    d <- runPostForm "/posts/1/delete" ""
    assertStatus 302 d
    assertHeader hLocation "/" d
    r <- runGet "/posts/1"
    assertStatus 404 r

-- 소유권/프로필 (2단계) --------------------------------------------------

-- 타인의 글은 수정·삭제할 수 없다(403). 글은 그대로 유지된다.
testOwnershipForbidden :: Test
testOwnershipForbidden = TestCase $ do
  (app, codeRef) <- mkAppC
  flip runSession app $ do
    _ <- verifiedSignup codeRef defaultUser -- Alice (id 1)
    _ <- publishViaPreview "title=Alice&body=Post"
    _ <- runPostForm "/logout" ""
    _ <- verifiedSignup codeRef secondUser -- Bob (id 2)
    e <- runGet "/posts/1/edit"
    assertStatus 403 e
    d <- runPostForm "/posts/1/delete" ""
    assertStatus 403 d
    -- 글은 여전히 존재한다.
    r <- runGet "/posts/1"
    assertStatus 200 r

-- 본인 프로필은 200이고, 사용자 이름과 작성한 글을 보여준다.
testProfileShowsOwnPosts :: Test
testProfileShowsOwnPosts = TestCase $ do
  (app, codeRef) <- mkAppC
  flip runSession app $ withUser codeRef $ do
    _ <- publishViaPreview "title=MyPost&body=B"
    r <- runGet "/profile"
    assertStatus 200 r
    assertBodyContains "Alice" r
    assertBodyContains "MyPost" r

-- 프로필 수정(소개)이 반영된다.
testProfileUpdate :: Test
testProfileUpdate = TestCase $ do
  (app, codeRef) <- mkAppC
  flip runSession app $ withUser codeRef $ do
    u <- runPostForm "/profile" "name=Alice&bio=Hello+there"
    assertStatus 302 u
    r <- runGet "/profile"
    assertBodyContains "Hello there" r

-- 공개 프로필(/users/:id)은 작성자 이름과 그 사람의 글을 보여준다.
testPublicProfile :: Test
testPublicProfile = TestCase $ do
  (app, codeRef) <- mkAppC
  flip runSession app $ withUser codeRef $ do
    _ <- publishViaPreview "title=PubPost&body=B"
    r <- runGet "/users/1"
    assertStatus 200 r
    assertBodyContains "Alice" r
    assertBodyContains "PubPost" r

-- 비밀번호 변경: 현재 비번 확인 → 새 비번으로만 로그인된다.
testPasswordChange :: Test
testPasswordChange = TestCase $ do
  (app, codeRef) <- mkAppC
  flip runSession app $ do
    _ <- verifiedSignup codeRef defaultUser
    c <- runPostForm "/profile/password" "current=secret12&new=newpass12&confirm=newpass12"
    assertStatus 302 c
    assertHeader hLocation "/profile" c
    _ <- runPostForm "/logout" ""
    old <- runPostForm "/login" "email=alice@example.com&password=secret12"
    assertStatus 400 old
    new <- runPostForm "/login" "email=alice@example.com&password=newpass12"
    assertStatus 302 new

-- 현재 비밀번호가 틀리면 변경 거부.
testPasswordWrongCurrent :: Test
testPasswordWrongCurrent = TestCase $ do
  (app, codeRef) <- mkAppC
  flip runSession app $ withUser codeRef $ do
    r <- runPostForm "/profile/password" "current=wrong-pw&new=newpass12&confirm=newpass12"
    assertStatus 400 r

-- 새 비밀번호 확인이 불일치하면 거부.
testPasswordMismatch :: Test
testPasswordMismatch = TestCase $ do
  (app, codeRef) <- mkAppC
  flip runSession app $ withUser codeRef $ do
    r <- runPostForm "/profile/password" "current=secret12&new=newpass12&confirm=different1"
    assertStatus 400 r

-- 새 비밀번호가 8자 미만이면 거부.
testPasswordTooShort :: Test
testPasswordTooShort = TestCase $ do
  (app, codeRef) <- mkAppC
  flip runSession app $ withUser codeRef $ do
    r <- runPostForm "/profile/password" "current=secret12&new=short&confirm=short"
    assertStatus 400 r

-- 테마 저장: 다크 저장 후 프로필이 data-theme="dark" 로 렌더된다.
testThemeSave :: Test
testThemeSave = TestCase $ do
  (app, codeRef) <- mkAppC
  flip runSession app $ withUser codeRef $ do
    s <- runPostForm "/profile/theme" "theme=dark"
    assertStatus 302 s
    r <- runGet "/profile"
    assertStatus 200 r
    assertBodyHas "data-theme=\"dark\"" r

-- GET /signup·/login 폼 페이지는 200으로 렌더된다(렌더러 진입 보장).
testGetSignupPage :: Test
testGetSignupPage = TestCase $ do
  app <- mkApp
  flip runSession app $ do
    r <- runGet "/signup"
    assertStatus 200 r
    assertBodyContains "<form" r

testGetLoginPage :: Test
testGetLoginPage = TestCase $ do
  app <- mkApp
  flip runSession app $ do
    r <- runGet "/login"
    assertStatus 200 r
    assertBodyContains "<form" r

-- 가입 입력값 검증: 이름이 비었거나 비밀번호가 8자 미만이면 400.
testSignupValidationEmptyName :: Test
testSignupValidationEmptyName = TestCase $ do
  app <- mkApp
  flip runSession app $ do
    r <- runPostForm "/signup" "email=a@b.com&name=&password=secret12"
    assertStatus 400 r

testSignupValidationShortPassword :: Test
testSignupValidationShortPassword = TestCase $ do
  app <- mkApp
  flip runSession app $ do
    r <- runPostForm "/signup" "email=a@b.com&name=Alice&password=short"
    assertStatus 400 r

-- 대기 항목이 없는 이메일로 코드를 인증하려 하면 400.
testVerifyNotFound :: Test
testVerifyNotFound = TestCase $ do
  app <- mkApp
  flip runSession app $ do
    r <- runPostForm "/signup/verify" "email=ghost@example.com&code=000000"
    assertStatus 400 r

-- 오답을 한도(5회)까지 반복하면 이후 시도는 시도횟수 초과로 거부된다.
testVerifyTooManyAttempts :: Test
testVerifyTooManyAttempts = TestCase $ do
  (app, codeRef) <- mkAppC
  flip runSession app $ do
    _ <- runPostForm "/signup" defaultUser
    real <- maybe "" id <$> liftIO (readIORef codeRef)
    let wrong = if real == "111111" then "222222" else "111111"
        wrongForm = LBS.fromStrict (TE.encodeUtf8 ("email=alice@example.com&code=" <> wrong))
    -- 한도까지 오답을 누적한 뒤(6번째) 시도횟수 초과 분기에 도달한다.
    rs <- mapM (const (runPostForm "/signup/verify" wrongForm)) [1 .. 6 :: Int]
    mapM_ (assertStatus 400) rs

-- 코드 재전송: 새 코드를 발급받아 그 코드로 인증하면 로그인된다.
testResendCode :: Test
testResendCode = TestCase $ do
  (app, codeRef) <- mkAppC
  flip runSession app $ do
    _ <- runPostForm "/signup" defaultUser
    rr <- runPostForm "/signup/resend" "email=alice@example.com"
    assertStatus 200 rr
    newCodeVal <- maybe "" id <$> liftIO (readIORef codeRef)
    v <-
      runPostForm
        "/signup/verify"
        (LBS.fromStrict (TE.encodeUtf8 ("email=alice@example.com&code=" <> newCodeVal)))
    assertStatus 302 v
    ok <- runGet "/posts/new"
    assertStatus 200 ok

-- 대기 항목이 없으면 재전송도 400.
testResendNotFound :: Test
testResendNotFound = TestCase $ do
  app <- mkApp
  flip runSession app $ do
    r <- runPostForm "/signup/resend" "email=ghost@example.com"
    assertStatus 400 r

-- 목록(/)에 글이 있으면 제목·작성자·작성일이 함께 렌더된다(작성자 본인 시점).
testIndexListsPosts :: Test
testIndexListsPosts = TestCase $ do
  (app, codeRef) <- mkAppC
  flip runSession app $ withUser codeRef $ do
    _ <- publishViaPreview "title=IndexPost&body=B"
    r <- runGet "/"
    assertStatus 200 r
    assertBodyContains "IndexPost" r
    assertBodyHas "Alice" r

-- 비로그인 시점에도 목록의 글과 작성자 링크가 보인다(소유자 아님 분기).
testIndexListsPostsAnon :: Test
testIndexListsPostsAnon = TestCase $ do
  (app, codeRef) <- mkAppC
  flip runSession app $ do
    _ <- withUser codeRef (publishViaPreview "title=AnonView&body=B")
    _ <- runPostForm "/logout" ""
    r <- runGet "/"
    assertStatus 200 r
    assertBodyContains "AnonView" r

-- 작성자 본인은 수정 폼(GET /posts/:id/edit)을 200으로 받는다.
testEditFormRendered :: Test
testEditFormRendered = TestCase $ do
  (app, codeRef) <- mkAppC
  flip runSession app $ withUser codeRef $ do
    _ <- publishViaPreview "title=Editable&body=Body"
    r <- runGet "/posts/1/edit"
    assertStatus 200 r
    assertBodyContains "Editable" r
    assertBodyContains "action=\"/posts/1/preview\"" r

-- 수정 미리보기에서 "수정"(draft)을 누르면 입력값을 유지한 채 수정 폼으로 돌아간다.
testEditDraftBack :: Test
testEditDraftBack = TestCase $ do
  (app, codeRef) <- mkAppC
  flip runSession app $ withUser codeRef $ do
    _ <- publishViaPreview "title=Old&body=B"
    d <- runPostForm "/posts/1/draft" "title=Kept&body=Stay"
    assertStatus 200 d
    assertBodyContains "Kept" d
    assertBodyContains "Stay" d

-- 라이브 미리보기 조각: 본문을 Org 로 렌더한 HTML 조각만 200으로 돌려준다.
testPreviewFragment :: Test
testPreviewFragment = TestCase $ do
  app <- mkApp
  flip runSession app $ do
    r <- runPostForm "/preview-fragment" "body=*heading*"
    assertStatus 200 r
    assertBodyContains "<b>heading</b>" r

-- 프로필 수정 시 이름이 비면 400.
testProfileEmptyName :: Test
testProfileEmptyName = TestCase $ do
  (app, codeRef) <- mkAppC
  flip runSession app $ withUser codeRef $ do
    r <- runPostForm "/profile" "name=&bio=x"
    assertStatus 400 r

-- 없는 사용자의 공개 프로필은 404.
testPublicProfileNotFound :: Test
testPublicProfileNotFound = TestCase $ do
  app <- mkApp
  flip runSession app $ do
    r <- runGet "/users/999"
    assertStatus 404 r

-- 비로그인 사용자가 글 단건을 조회하면 200이고, 수정/삭제 버튼은 보이지 않는다
-- (renderPost 의 비소유자 분기).
testPostViewAnon :: Test
testPostViewAnon = TestCase $ do
  (app, codeRef) <- mkAppC
  flip runSession app $ do
    _ <- withUser codeRef (publishViaPreview "title=Readable&body=Body")
    _ <- runPostForm "/logout" ""
    r <- runGet "/posts/1"
    assertStatus 200 r
    assertBodyContains "Readable" r
    assertBodyExcludes "삭제" r

routeTests :: Test
routeTests =
  TestList
    [ testHealth
    , testEmptyIndex
    , testNewButtonHiddenAnon
    , testNewButtonShownAuth
    , testNotFound
    , testProtectedRedirectsAnon
    , testSignupCreatesSession
    , testSignupRequiresVerification
    , testSignupWrongCode
    , testSignupDuplicateEmail
    , testLoginWrongPassword
    , testLoginLogoutFlow
    , testCreateAndRead
    , testPublishWithoutTokenRejected
    , testPublishTamperedRejected
    , testPreview
    , testDraftBack
    , testUpdate
    , testUpdateWithoutTokenRejected
    , testCrossTargetTokenRejected
    , testDelete
    , testOwnershipForbidden
    , testProfileShowsOwnPosts
    , testProfileUpdate
    , testPublicProfile
    , testPasswordChange
    , testPasswordWrongCurrent
    , testPasswordMismatch
    , testPasswordTooShort
    , testThemeSave
    , testGetSignupPage
    , testGetLoginPage
    , testSignupValidationEmptyName
    , testSignupValidationShortPassword
    , testVerifyNotFound
    , testVerifyTooManyAttempts
    , testResendCode
    , testResendNotFound
    , testIndexListsPosts
    , testIndexListsPostsAnon
    , testEditFormRendered
    , testEditDraftBack
    , testPreviewFragment
    , testProfileEmptyName
    , testPublicProfileNotFound
    , testPostViewAnon
    ]
