{-# LANGUAGE DataKinds         #-}
{-# LANGUAGE OverloadedStrings #-}

-- | 파생 'Show'/'Eq' 인스턴스 단위 테스트.
--
-- 도메인 값 타입들이 파생(@deriving stock@)한 'Show'/'Eq' 인스턴스를 직접
-- 잠근다. 라우트·로직 테스트는 위치 생성자·패턴 매칭만 쓰느라 이 인스턴스
-- 메서드(@show@, @==@, @/=@)를 호출하지 않아 닿지 않는다. 여기서는 각 타입에
-- 대해 (1) @show@ 결과를 정확한 문자열과 대조하고, (2) 같은 값/다른 값의
-- @==@·@/=@ 를 모두 평가해 양쪽 분기를 강제한다.
module DerivingSpec
  ( derivingTests
  ) where

import Data.Time (UTCTime (..), fromGregorian, secondsToDiffTime)
import Test.HUnit

import Blog.Email (Code (..))
import Blog.Post (NewPost (..), Post (..), PostView (..))
import Blog.Publish (PostTarget (..), Token (..), mkDraft, signDraft, verifyPreviewed)
import Blog.User (NewUser (..), Theme (..), User (..), UserError (..))
import Blog.Verification (CodeCheck (..), PendingSignup (..))

mkTime :: UTCTime
mkTime = UTCTime (fromGregorian 2026 1 1) (secondsToDiffTime 0)

-- | 같은 값은 @==@, 한 군데라도 다른 값은 @/=@ 임을 확인하고(양쪽 분기),
--   @show@ 결과가 비지 않음을 확인한다(파생 'Show' 강제).
--
-- 파생 'Show' 는 @showsPrec@·@show@·@showList@ 세 메서드를 만든다. @show x@ 는
-- 앞 둘만 호출하므로, 리스트를 보여 @showList@ 까지 친다(@show [x]@ 가
-- 원소 타입의 @showList@ 를 호출한다).
eqShow :: (Eq a, Show a) => a -> a -> Assertion
eqShow same other = do
  assertBool "reflexive ==" (same == same)
  assertBool "distinct /=" (same /= other)
  assertBool "not (same == other)" (not (same == other))
  assertBool "show non-empty" (length (show same) > 0)
  assertBool "show other non-empty" (length (show other) > 0)
  assertBool "showList non-empty" (length (show [same, other]) > 0)

derivingTests :: Test
derivingTests =
  TestList
    [ themeDeriving
    , userDeriving
    , postDeriving
    , emailDeriving
    , publishDeriving
    , verificationDeriving
    ]

-- Blog.User -------------------------------------------------------------

themeDeriving :: Test
themeDeriving =
  TestLabel "Theme 파생 Show/Eq" . TestCase $ do
    eqShow Light Dark
    assertEqual "show Light" "Light" (show Light)
    assertEqual "show Dark" "Dark" (show Dark)

userDeriving :: Test
userDeriving =
  TestLabel "User/NewUser/UserError 파생 Show/Eq" . TestCase $ do
    let u = User 1 "a@b.com" "Alice" "bio" "hash" mkTime Light
    -- 각 필드를 한 군데씩 바꿔 파생 == 의 필드별 비교 분기를 모두 친다.
    eqShow u u {userId = 2}
    eqShow u u {userEmail = "z@b.com"}
    eqShow u u {userName = "Bob"}
    eqShow u u {userBio = "other"}
    eqShow u u {userPasswordHash = "h2"}
    eqShow u u {userTheme = Dark}
    let nu = NewUser "a@b.com" "Alice" "hash"
    eqShow nu nu {newUserEmail = "z@b.com"}
    eqShow nu nu {newUserName = "Bob"}
    eqShow nu nu {newUserPasswordHash = "h2"}
    eqShow EmailTaken (OtherUserError "boom")
    eqShow (OtherUserError "a") (OtherUserError "b")
    assertEqual "show EmailTaken" "EmailTaken" (show EmailTaken)

-- Blog.Post -------------------------------------------------------------

postDeriving :: Test
postDeriving =
  TestLabel "Post/PostView/NewPost 파생 Show/Eq" . TestCase $ do
    let p = Post 1 "Title" "Body" mkTime 7
    eqShow p p {postId = 2}
    eqShow p p {postTitle = "Other"}
    eqShow p p {postBody = "Other"}
    eqShow p p {postAuthorId = 8}
    let pv = PostView p "Author"
    eqShow pv pv {pvAuthorName = "Other"}
    eqShow pv pv {pvPost = p {postId = 99}}
    let np = NewPost "T" "B"
    eqShow np np {newPostTitle = "X"}
    eqShow np np {newPostBody = "Y"}

-- Blog.Email ------------------------------------------------------------

emailDeriving :: Test
emailDeriving =
  TestLabel "Code 파생 Show/Eq" . TestCase $ do
    eqShow (Code "123456") (Code "654321")
    assertBool "show shows digits" ('1' `elem` show (Code "123456"))

-- Blog.Publish ----------------------------------------------------------

publishDeriving :: Test
publishDeriving =
  TestLabel "Article/PostTarget/Token 파생 Show/Eq" . TestCase $ do
    -- PostTarget: 두 생성자 + EditTarget 인자 차이 모두.
    eqShow NewTarget (EditTarget 1)
    eqShow (EditTarget 1) (EditTarget 2)
    assertEqual "show NewTarget" "NewTarget" (show NewTarget)
    -- Token: 서명 결과. 같은 입력은 같은 토큰, 다른 입력은 다른 토큰.
    let t1 = signDraft "k" NewTarget (mkDraft "t" "b")
        t2 = signDraft "k" NewTarget (mkDraft "t" "different")
    eqShow t1 t2
    assertBool "token show non-empty" (length (show (unToken t1)) > 0)
    -- Article: 생성자가 노출되지 않으므로 mkDraft(Draft)/verifyPreviewed(Previewed)로 얻는다.
    let d1 = mkDraft "t" "b"
        d2 = mkDraft "t" "other"
    eqShow d1 d2
    case verifyPreviewed "k" NewTarget "t" "b" t1 of
      Just a1 -> assertBool "previewed show non-empty" (length (show a1) > 0)
      Nothing -> assertFailure "올바른 토큰의 검증이 실패했다"

-- Blog.Verification -----------------------------------------------------

verificationDeriving :: Test
verificationDeriving =
  TestLabel "PendingSignup/CodeCheck 파생 Show/Eq" . TestCase $ do
    let pend = PendingSignup "a@b.com" "Alice" "pwhash" "codehash" mkTime 0
    eqShow pend pend {pendingEmail = "z@b.com"}
    eqShow pend pend {pendingName = "Bob"}
    eqShow pend pend {pendingPasswordHash = "h2"}
    eqShow pend pend {pendingCodeHash = "c2"}
    eqShow pend pend {pendingAttempts = 3}
    -- CodeCheck: 네 생성자 간 모든 구분.
    eqShow Valid Expired
    eqShow Expired TooManyAttempts
    eqShow TooManyAttempts WrongCode
    assertEqual "show Valid" "Valid" (show Valid)
