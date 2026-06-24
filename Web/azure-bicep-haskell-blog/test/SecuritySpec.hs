{-# LANGUAGE OverloadedStrings #-}

-- | 보안 핵심 순수 로직 단위 테스트.
--
-- 라우트 통합 테스트로는 간접적으로만 닿던 서명·검증 로직을 직접 잠근다:
-- (1) 'Blog.Publish' 미리보기 토큰 서명/검증(위조·변조·대상 불일치),
-- (2) 'Blog.Auth' 세션 쿠키 왕복·만료·변조와 비밀번호 해시,
-- (3) 'Blog.Keys' 도메인 분리 키 파생.
module SecuritySpec
  ( securityTests
  ) where

import Data.Text qualified as T
import Data.Time (UTCTime (..), fromGregorian, secondsToDiffTime)
import Test.HUnit

import Blog.Auth
  ( AuthUser
  , authedUser
  , hashPassword
  , makeSessionValue
  , resolveSession
  , verifyPassword
  )
import Blog.Keys (AppKeys (..), deriveKeys)
import Blog.Publish
  ( PostTarget (..)
  , articleBody
  , articleTitle
  , mkDraft
  , signDraft
  , verifyPreviewed
  )
import Blog.User (Theme (..), User (..))
import Blog.Verification (CodeCheck (..), PendingSignup (..), checkCode)

mkTime :: Integer -> Int -> Int -> UTCTime
mkTime y m d = UTCTime (fromGregorian y m d) (secondsToDiffTime 0)

-- | 세션 복원이 id로 조회하는 가짜 사용자.
sampleUser :: Int -> User
sampleUser uid = User uid "a@b.com" "Alice" "" "hash" (mkTime 2026 1 1) Light

lookupUser :: Int -> IO (Maybe User)
lookupUser = pure . Just . sampleUser

securityTests :: Test
securityTests = TestList [articleTests, sessionTests, passwordTests, secretTests, checkCodeTests]

-- 미리보기 토큰 ----------------------------------------------------------

articleTests :: Test
articleTests =
  TestList
    [ TestLabel "서명한 토큰은 같은 대상·내용으로 검증된다" . TestCase $ do
        let sig = signDraft "k" NewTarget (mkDraft "t" "b")
        assertEqual
          "title"
          (Just "t")
          (articleTitle <$> verifyPreviewed "k" NewTarget "t" "b" sig)
        assertEqual
          "body"
          (Just "b")
          (articleBody <$> verifyPreviewed "k" NewTarget "t" "b" sig)
    , TestLabel "본문이 변조되면 검증에 실패한다" . TestCase $ do
        let sig = signDraft "k" NewTarget (mkDraft "t" "b")
        assertEqual
          "tampered"
          Nothing
          (articleTitle <$> verifyPreviewed "k" NewTarget "t" "evil" sig)
    , TestLabel "대상이 다르면(새 글↔수정) 검증에 실패한다" . TestCase $ do
        let sig = signDraft "k" NewTarget (mkDraft "t" "b")
        assertEqual
          "cross-target"
          Nothing
          (articleTitle <$> verifyPreviewed "k" (EditTarget 1) "t" "b" sig)
    , TestLabel "다른 글 id 의 수정 토큰은 재사용할 수 없다" . TestCase $ do
        let sig = signDraft "k" (EditTarget 1) (mkDraft "t" "b")
        assertEqual
          "other id"
          Nothing
          (articleTitle <$> verifyPreviewed "k" (EditTarget 2) "t" "b" sig)
    , TestLabel "키가 다르면 검증에 실패한다(위조 방지)" . TestCase $ do
        let sig = signDraft "k" NewTarget (mkDraft "t" "b")
        assertEqual
          "wrong key"
          Nothing
          (articleTitle <$> verifyPreviewed "other" NewTarget "t" "b" sig)
    ]

-- 세션 쿠키 --------------------------------------------------------------

resolvedId :: Maybe AuthUser -> Maybe Int
resolvedId = fmap (userId . authedUser)

sessionTests :: Test
sessionTests =
  TestList
    [ TestLabel "유효한 세션은 같은 사용자 id 로 복원된다" . TestCase $ do
        let val = makeSessionValue "k" 42 (mkTime 2030 1 1)
        mAuth <- resolveSession "k" (mkTime 2026 6 20) lookupUser val
        assertEqual "uid" (Just 42) (resolvedId mAuth)
    , TestLabel "만료된 세션은 복원되지 않는다" . TestCase $ do
        let val = makeSessionValue "k" 42 (mkTime 2020 1 1)
        mAuth <- resolveSession "k" (mkTime 2026 6 20) lookupUser val
        assertEqual "expired" Nothing (resolvedId mAuth)
    , TestLabel "변조된 쿠키는 복원되지 않는다" . TestCase $ do
        let val = makeSessionValue "k" 42 (mkTime 2030 1 1)
            tampered = T.snoc (T.init val) (if T.last val == '0' then '1' else '0')
        mAuth <- resolveSession "k" (mkTime 2026 6 20) lookupUser tampered
        assertEqual "tampered" Nothing (resolvedId mAuth)
    , TestLabel "다른 키로는 세션이 복원되지 않는다" . TestCase $ do
        let val = makeSessionValue "k" 42 (mkTime 2030 1 1)
        mAuth <- resolveSession "other" (mkTime 2026 6 20) lookupUser val
        assertEqual "wrong key" Nothing (resolvedId mAuth)
    ]

-- 비밀번호 ---------------------------------------------------------------

passwordTests :: Test
passwordTests =
  TestList
    [ TestLabel "해시한 비밀번호는 원문으로 검증된다" . TestCase $ do
        h <- hashPassword "secret12"
        assertBool "match" (verifyPassword "secret12" h)
        assertBool "mismatch" (not (verifyPassword "wrong-pw" h))
    ]

-- 키 파생 ----------------------------------------------------------------

secretTests :: Test
secretTests =
  TestList
    [ TestLabel "토큰 키와 세션 키는 서로 다르다(도메인 분리)" . TestCase $
        assertBool "distinct" (tokenKey (deriveKeys "master") /= sessionKey (deriveKeys "master"))
    , TestLabel "같은 마스터는 같은 키를, 다른 마스터는 다른 키를 낸다" . TestCase $ do
        assertEqual
          "deterministic"
          (tokenKey (deriveKeys "master"))
          (tokenKey (deriveKeys "master"))
        assertBool "master matters" (tokenKey (deriveKeys "a") /= tokenKey (deriveKeys "b"))
    ]

-- 코드 검증 판정 ---------------------------------------------------------

pendingWith :: UTCTime -> Int -> PendingSignup
pendingWith expires attempts = PendingSignup "a@b.com" "Alice" "pwhash" "CODEHASH" expires attempts

checkCodeTests :: Test
checkCodeTests =
  TestList
    [ TestLabel "올바른 코드·미만료·시도 여유면 Valid" . TestCase $
        assertEqual
          "valid"
          Valid
          (checkCode (mkTime 2026 6 20) 5 "CODEHASH" (pendingWith (mkTime 2030 1 1) 0))
    , TestLabel "만료되면 Expired" . TestCase $
        assertEqual
          "expired"
          Expired
          (checkCode (mkTime 2026 6 20) 5 "CODEHASH" (pendingWith (mkTime 2020 1 1) 0))
    , TestLabel "시도 횟수를 초과하면 TooManyAttempts" . TestCase $
        assertEqual
          "too many"
          TooManyAttempts
          (checkCode (mkTime 2026 6 20) 5 "CODEHASH" (pendingWith (mkTime 2030 1 1) 5))
    , TestLabel "코드 해시가 다르면 WrongCode" . TestCase $
        assertEqual
          "wrong"
          WrongCode
          (checkCode (mkTime 2026 6 20) 5 "NOPE" (pendingWith (mkTime 2030 1 1) 0))
    ]
