-- | 인증·회원가입 라우트 — 가입(2단계 이메일 인증)·로그인·로그아웃.
module Blog.App.AuthRoutes
  ( authRoutes
  ) where

import Control.Monad.IO.Class (liftIO)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Time.Clock (addUTCTime, getCurrentTime)
import Network.HTTP.Types.Status (badRequest400)
import Web.Scotty (ActionM, ScottyM, formParam, get, post, redirect, status)

import Blog.App.Common
  ( Env (..)
  , currentViewer
  , endSession
  , hashCode
  , renderView
  , startSession
  )
import Blog.Auth (hashPassword, verifyPassword)
import Blog.Email (Code (..), EmailSender (..), newCode)
import Blog.Routes qualified as R
import Blog.User (NewUser (..), User (..), UserError (..), UserStore (..))
import Blog.Verification
  ( CodeCheck (..)
  , PendingSignup (..)
  , VerificationStore (..)
  , checkCode
  )
import Blog.View (renderLogin, renderSignup, renderVerify)

-- | 가입 인증 코드 유효 기간(초). 10분.
verifyTtlSeconds :: Int
verifyTtlSeconds = 10 * 60

-- | 코드 입력 허용 오답 횟수. 초과 시 대기 항목을 폐기한다.
maxVerifyAttempts :: Int
maxVerifyAttempts = 5

authRoutes :: Env -> ScottyM ()
authRoutes env = do
  get R.signup $ do
    viewer <- currentViewer env
    renderView (renderSignup viewer Nothing)

  -- 가입 1단계: 입력값 검증 → 인증 코드 발송 → 코드 입력 페이지.
  post R.signup $ do
    email <- formParam "email"
    name <- formParam "name"
    pw <- formParam "password"
    if T.null (T.strip email) || T.null (T.strip name) || T.length pw < 8
      then signupError "이메일·표시 이름·8자 이상 비밀번호를 모두 입력하세요."
      else do
        existing <- liftIO (userByEmail (envUsers env) email)
        case existing of
          Just _  -> signupError "이미 사용 중인 이메일입니다."
          Nothing -> sendVerification env email name pw

  -- 가입 2단계: 코드 검증 → 검증되면 그때 계정 생성 + 자동 로그인.
  post R.signupVerify $ do
    email <- formParam "email"
    code <- formParam "code"
    mp <- liftIO (getPending (envVerify env) email)
    now <- liftIO getCurrentTime
    case mp of
      Nothing -> verifyError email "인증 요청을 찾을 수 없습니다. 회원가입을 다시 시도하세요."
      Just p -> case checkCode now maxVerifyAttempts (hashCode env code) p of
        Expired -> do
          liftIO (deletePending (envVerify env) email)
          verifyError email "인증 코드가 만료되었습니다. 코드를 다시 받아 주세요."
        TooManyAttempts -> do
          liftIO (deletePending (envVerify env) email)
          verifyError email "시도 횟수를 초과했습니다. 회원가입을 다시 시도하세요."
        WrongCode -> do
          liftIO (bumpAttempts (envVerify env) email)
          verifyError email "인증 코드가 올바르지 않습니다."
        Valid -> do
          res <-
            liftIO (userInsert (envUsers env) (NewUser email (pendingName p) (pendingPasswordHash p)))
          liftIO (deletePending (envVerify env) email)
          case res of
            Right user                -> startSession env user >> redirect R.home
            Left EmailTaken           -> signupError "이미 사용 중인 이메일입니다."
            Left (OtherUserError msg) -> signupError msg

  -- 코드 재전송: 새 코드로 교체하고 다시 발송한다.
  post R.signupResend $ do
    email <- formParam "email"
    mp <- liftIO (getPending (envVerify env) email)
    case mp of
      Nothing -> signupError "인증 요청을 찾을 수 없습니다. 회원가입을 다시 시도하세요."
      Just p -> do
        code <- liftIO newCode
        now <- liftIO getCurrentTime
        let expiry = addUTCTime (fromIntegral verifyTtlSeconds) now
        liftIO
          ( storePending
              (envVerify env)
              p
                { pendingCodeHash = hashCode env (unCode code)
                , pendingExpiresAt = expiry
                , pendingAttempts = 0
                }
          )
        liftIO (sendCode (envSender env) email code)
        renderView (renderVerify email Nothing)

  get R.login $ do
    viewer <- currentViewer env
    renderView (renderLogin viewer Nothing)

  post R.login $ do
    email <- formParam "email"
    pw <- formParam "password"
    mUser <- liftIO (userByEmail (envUsers env) email)
    case mUser of
      Just u
        | verifyPassword pw (userPasswordHash u) ->
            startSession env u >> redirect R.home
      _ -> do
        status badRequest400
        renderView (renderLogin Nothing (Just "이메일 또는 비밀번호가 올바르지 않습니다."))

  post R.logout $ do
    endSession
    redirect R.home

-- | 회원가입 오류를 400과 함께 폼에 다시 띄운다.
signupError :: Text -> ActionM ()
signupError msg = do
  status badRequest400
  renderView (renderSignup Nothing (Just msg))

-- | 인증 코드를 발급·저장·발송하고 코드 입력 페이지를 보인다(가입 1단계 본체).
--   비밀번호와 코드는 모두 해시로만 대기 저장하고, 검증 후에야 실제 계정을 만든다.
sendVerification :: Env -> Text -> Text -> Text -> ActionM ()
sendVerification env email name pw = do
  pwHash <- liftIO (hashPassword pw)
  code <- liftIO newCode
  now <- liftIO getCurrentTime
  let expiry = addUTCTime (fromIntegral verifyTtlSeconds) now
  liftIO
    ( storePending
        (envVerify env)
        (PendingSignup email name pwHash (hashCode env (unCode code)) expiry 0)
    )
  liftIO (sendCode (envSender env) email code)
  renderView (renderVerify email Nothing)

-- | 코드 입력 오류를 400과 함께 인증 페이지에 다시 띄운다.
verifyError :: Text -> Text -> ActionM ()
verifyError email msg = do
  status badRequest400
  renderView (renderVerify email (Just msg))
