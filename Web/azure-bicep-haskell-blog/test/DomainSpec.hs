{-# LANGUAGE OverloadedStrings #-}

-- | 도메인 값 타입과 설정 로더의 단위 테스트.
--
-- 라우트·렌더러 테스트가 위치 생성자·패턴 매칭만 쓰느라 닿지 않던
-- (1) 레코드 필드 접근자, (2) 파생 'Show'/'Eq' 인스턴스,
-- (3) 'Theme' 직렬화/역직렬화, (4) 'Blog.Config.loadConfig' 의 환경 변수
-- 해석(포트 기본값·DATABASE_URL 누락·PREVIEW_SECRET fail-closed 와 opt-in)을 직접 잠근다.
module DomainSpec
  ( domainTests
  ) where

import Data.Time (UTCTime (..), fromGregorian, secondsToDiffTime)
import System.Environment (setEnv, unsetEnv)
import Test.HUnit

import Blog.Config (AppConfig (..), loadConfig)
import Blog.Email (Code (..), EmailSender (..), logEmailSender)
import Blog.Post (NewPost (..), Post (..), PostView (..))
import Blog.User
  ( NewUser (..)
  , Theme (..)
  , User (..)
  , UserError (..)
  , parseTheme
  , renderTheme
  )

mkTime :: UTCTime
mkTime = UTCTime (fromGregorian 2026 1 1) (secondsToDiffTime 0)

domainTests :: Test
domainTests = TestList [themeTests, userTypeTests, postTypeTests, configTests, emailTests]

-- Theme 직렬화 ----------------------------------------------------------

themeTests :: Test
themeTests =
  TestList
    [ TestLabel "renderTheme 는 light/dark 로 직렬화한다" . TestCase $ do
        assertEqual "light" "light" (renderTheme Light)
        assertEqual "dark" "dark" (renderTheme Dark)
    , TestLabel "parseTheme 는 dark 만 Dark, 나머지는 Light" . TestCase $ do
        assertEqual "dark" Dark (parseTheme "dark")
        assertEqual "other" Light (parseTheme "system")
        assertEqual "empty" Light (parseTheme "")
    , TestLabel "Theme 의 Eq/Show 가 동작한다" . TestCase $ do
        assertBool "eq" (Light == Light && Dark == Dark)
        assertBool "neq" (Light /= Dark)
        assertEqual "show" "Light" (show Light)
    ]

-- 사용자 타입 ----------------------------------------------------------

userTypeTests :: Test
userTypeTests =
  TestList
    [ TestLabel "NewUser 필드 접근자와 Eq/Show" . TestCase $ do
        let nu = NewUser "a@b.com" "Alice" "hash"
        assertEqual "email" "a@b.com" (newUserEmail nu)
        assertEqual "name" "Alice" (newUserName nu)
        assertEqual "hash" "hash" (newUserPasswordHash nu)
        assertEqual "eq" nu (NewUser "a@b.com" "Alice" "hash")
        assertBool "show" (not (null (show nu)))
    , TestLabel "User 의 Eq/Show" . TestCase $ do
        let u = User 1 "a@b.com" "Alice" "bio" "hash" mkTime Light
        assertEqual "eq" u u
        assertBool "show" (not (null (show u)))
    , TestLabel "UserError 의 Eq/Show" . TestCase $ do
        assertEqual "taken" EmailTaken EmailTaken
        assertBool "neq" (EmailTaken /= OtherUserError "x")
        assertBool "show taken" (not (null (show EmailTaken)))
        assertBool "show other" (not (null (show (OtherUserError "boom"))))
    ]

-- 글 타입 --------------------------------------------------------------

postTypeTests :: Test
postTypeTests =
  TestList
    [ TestLabel "Post/PostView/NewPost 필드 접근자와 Eq/Show" . TestCase $ do
        let p = Post 1 "Title" "Body" mkTime 7
            pv = PostView p "Author"
            np = NewPost "T" "B"
        assertEqual "pvAuthorName" "Author" (pvAuthorName pv)
        assertEqual "pvPost" p (pvPost pv)
        assertEqual "newPostTitle" "T" (newPostTitle np)
        assertEqual "newPostBody" "B" (newPostBody np)
        assertEqual "post eq" p (Post 1 "Title" "Body" mkTime 7)
        assertEqual "view eq" pv (PostView p "Author")
        assertEqual "newpost eq" np (NewPost "T" "B")
        assertBool "post show" (not (null (show p)))
        assertBool "view show" (not (null (show pv)))
        assertBool "newpost show" (not (null (show np)))
    ]

-- 설정 로더 ------------------------------------------------------------

configTests :: Test
configTests =
  TestList
    [ TestLabel "DATABASE_URL 이 없으면 Left 로 실패한다" . TestCase $ do
        unsetEnv "DATABASE_URL"
        unsetEnv "PORT"
        unsetEnv "PREVIEW_SECRET"
        unsetEnv "ALLOW_INSECURE_SECRET"
        r <- loadConfig
        case r of
          Left e  -> assertBool "error message present" (not (null e))
          Right _ -> assertFailure "DATABASE_URL 없이 Right 가 나왔다"
    , TestLabel "PREVIEW_SECRET·ALLOW_INSECURE_SECRET 모두 없으면 fail-closed(Left)" . TestCase $ do
        -- 공개된 개발용 기본키로 조용히 기동하지 않도록 기동을 거부한다.
        setEnv "DATABASE_URL" "postgresql://localhost/db"
        unsetEnv "PORT"
        unsetEnv "PREVIEW_SECRET"
        unsetEnv "ALLOW_INSECURE_SECRET"
        r <- loadConfig
        case r of
          Left e  -> assertBool "error message present" (not (null e))
          Right _ -> assertFailure "PREVIEW_SECRET 없이 Right 가 나왔다(fail-closed 위반)"
    , TestLabel "ALLOW_INSECURE_SECRET=1 이면 개발용 기본키로 로드된다(명시적 opt-in)" . TestCase $ do
        setEnv "DATABASE_URL" "postgresql://localhost/db"
        unsetEnv "PORT"
        unsetEnv "PREVIEW_SECRET"
        setEnv "ALLOW_INSECURE_SECRET" "1"
        r <- loadConfig
        case r of
          Left e -> assertFailure ("예상치 못한 실패: " <> e)
          Right c -> do
            assertEqual "default port" 8080 (configPort c)
            assertBool "insecure key flagged" (configInsecureKey c)
            assertEqual "dev key" "dev-insecure-secret-key" (configSecretKey c)
            assertEqual "db url" "postgresql://localhost/db" (configDatabaseUrl c)
        unsetEnv "ALLOW_INSECURE_SECRET"
    , TestLabel "PORT·PREVIEW_SECRET 가 있으면 그 값으로 로드된다" . TestCase $ do
        setEnv "DATABASE_URL" "postgresql://localhost/db"
        setEnv "PORT" "9090"
        setEnv "PREVIEW_SECRET" "topsecret"
        unsetEnv "ALLOW_INSECURE_SECRET"
        r <- loadConfig
        case r of
          Left e -> assertFailure ("예상치 못한 실패: " <> e)
          Right c -> do
            assertEqual "custom port" 9090 (configPort c)
            assertEqual "secret key" "topsecret" (configSecretKey c)
            assertBool "secure key" (not (configInsecureKey c))
        unsetEnv "PORT"
        unsetEnv "PREVIEW_SECRET"
    ]

-- 이메일 ---------------------------------------------------------------

emailTests :: Test
emailTests =
  TestList
    [ TestLabel "Code 의 Eq/Show" . TestCase $ do
        assertEqual "eq" (Code "123456") (Code "123456")
        assertBool "neq" (Code "111111" /= Code "222222")
        assertEqual "unCode" "123456" (unCode (Code "123456"))
        assertBool "show" (not (null (show (Code "123456"))))
    , TestLabel "logEmailSender 는 코드 발송을 IO 로 수행한다(stderr 출력)" . TestCase $
        -- 개발용 어댑터는 실제 발송 대신 stderr 로 찍고 () 를 돌려준다.
        sendCode logEmailSender "user@example.com" (Code "654321")
    ]
