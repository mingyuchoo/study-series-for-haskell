{-# LANGUAGE RecordWildCards #-}

-- | 인증/카탈로그 핸들러 (회원가입, 로그인, 로그아웃, 체크리스트 목록).
module Luck.Handler.Auth
    ( catalogH
    , loginH
    , logoutH
    , signupRequestH
    , signupVerifyH
    ) where

import           Control.Monad                 (when)
import           Control.Monad.Except          (throwError)
import           Control.Monad.IO.Class        (liftIO)
import           Control.Monad.Reader          (ask)
import qualified Data.Text                     as T
import           Data.Time                     (addUTCTime, getCurrentTime)
import           Data.UUID.V4                  (nextRandom)
import           Luck.App                      (AppEnv (..), AppM)
import           Luck.Auth                     (genVerificationCode, hashPassword, issueToken, verifyPassword)
import           Luck.Config                   (Config (..))
import           Luck.Domain.Admin             (AdminGrant (..), adminGrant)
import           Luck.Email                    (sendVerificationCode)
import           Luck.Domain.Validation        (validateSignup)
import           Luck.Error                    (DomainError (..))
import           Luck.Handler.Util             (liftEither, runDB)
import           Luck.Repository.Checklist     (listItems)
import           Luck.Repository.User          (UserRow (..), getUserByEmail, insertUser)
import           Luck.Repository.Verification
    ( VerificationRow (..)
    , deleteVerification
    , getVerification
    , upsertVerification
    )
import           Luck.Types.Auth
    ( AuthResp (..)
    , AuthUser (..)
    , LoginReq (..)
    , SignupReq (..)
    , VerifyReq (..)
    )
import           Luck.Types.Checklist          (CatalogItem)
import           Luck.Types.Common             (MessageResp (..))
import           Luck.Web.Dto                  (checklistItemToCatalog, userRowToDTO)
import           Luck.Web.Error                (toServerError)

-- | 인증번호 유효시간 (초). 이메일로 받은 6자리를 이 시간 안에 입력해야 한다.
--   메일 전송 지연·스팸함 확인 시간을 감안해 넉넉히 15분.
verificationTtlSeconds :: Num a => a
verificationTtlSeconds = 15 * 60

-- | 1단계: 가입 정보를 검증하고 인증번호를 발급한다.
--   비밀번호 해시·이름을 인증 대기 테이블에 임시 저장하고, 6자리 코드를
--   생성해 이메일로 발송한다(ACS). 토큰은 아직 없다.
signupRequestH :: SignupReq -> AppM MessageResp
signupRequestH req@SignupReq {..} = do
  liftEither (validateSignup req)
  let email = T.strip srEmail
  ensureEmailAvailable email
  pwHash <- hashOrFail srPassword
  code <- liftIO genVerificationCode
  expiresAt <- addUTCTime verificationTtlSeconds <$> liftIO getCurrentTime
  runDB (\p -> upsertVerification p email pwHash srDisplayName code expiresAt)
  sendCodeOrFail email srDisplayName code
  pure (MessageResp "인증번호를 이메일로 발송했습니다. 메일함(스팸함 포함)을 확인하고 6자리 번호를 입력하세요.")

-- | 이미 가입된 이메일이면 가입을 막는다(EmailTaken).
ensureEmailAvailable :: T.Text -> AppM ()
ensureEmailAvailable email = do
  existing <- runDB (\p -> getUserByEmail p email)
  case existing of
    Just _  -> throwError (toServerError EmailTaken)
    Nothing -> pure ()

-- | 비밀번호를 해시한다. 해시 실패 시 500.
hashOrFail :: T.Text -> AppM T.Text
hashOrFail pw = do
  mh <- liftIO (hashPassword pw)
  maybe (throwError (toServerError (InternalError "비밀번호 처리 중 오류가 발생했습니다."))) pure mh

-- | 인증번호 이메일을 발송한다. 실패 시 로그를 남기고 500.
sendCodeOrFail :: T.Text -> T.Text -> T.Text -> AppM ()
sendCodeOrFail email displayName code = do
  sender <- envEmail <$> ask
  sent <- liftIO (sendVerificationCode sender email displayName code)
  case sent of
    Right () -> pure ()
    Left e -> do
      liftIO $
        putStrLn ("[SIGNUP] email send failed for " <> T.unpack email <> ": " <> T.unpack e)
      throwError (toServerError (InternalError "인증번호 이메일 발송에 실패했습니다. 잠시 후 다시 시도해 주세요."))

-- | 2단계: 인증번호를 확인하고 실제 사용자를 생성한다.
--   코드 일치 + 미만료면 'insertUser' 로 승격하고 토큰을 발급한 뒤 대기 행을 삭제한다.
signupVerifyH :: VerifyReq -> AppM AuthResp
signupVerifyH VerifyReq {..} = do
  let email = T.strip veEmail
      badCode = ValidationError "인증번호가 올바르지 않거나 만료되었습니다."
  mrow <- runDB (\p -> getVerification p email)
  row <-
    case mrow of
      Just r -> pure r
      Nothing -> do
        liftIO $ putStrLn ("[VERIFY] no pending row for " <> T.unpack email)
        throwError (toServerError badCode)
  now <- liftIO getCurrentTime
  let codeMismatch = vrCode row /= T.strip veCode
      expired = vrExpiresAt row < now
  when (codeMismatch || expired) $ do
    liftIO $
      putStrLn
        ("[VERIFY] reject for "
           <> T.unpack email
           <> (if codeMismatch then " codeMismatch" else "")
           <> (if expired then " expired" else ""))
    throwError (toServerError badCode)
  uid <- liftIO nextRandom
  admins <- cfgAdminEmails . envConfig <$> ask
  let grant = adminGrant admins (vrEmail row)
  inserted <-
    liftEither
      =<< runDB
        (\p -> insertUser p uid (vrEmail row) (vrPasswordHash row) (vrDisplayName row) (agExplicit grant) (agFirstUserFallback grant))
  runDB (\p -> deleteVerification p email)
  mkAuthResp inserted

loginH :: LoginReq -> AppM AuthResp
loginH LoginReq {..} = do
  mrow <- runDB (\p -> getUserByEmail p lrEmail)
  case mrow of
    Just row | verifyPassword lrPassword (urPasswordHash row) -> mkAuthResp row
    _ -> throwError (toServerError InvalidCredentials)

logoutH :: AppM MessageResp
logoutH = pure (MessageResp "로그아웃되었습니다. 클라이언트에서 토큰을 삭제하세요.")

catalogH :: AppM [CatalogItem]
catalogH = map checklistItemToCatalog <$> runDB listItems

-- | 토큰 + 사용자 DTO 응답을 만든다.
mkAuthResp :: UserRow -> AppM AuthResp
mkAuthResp row = do
  env <- ask
  let au = AuthUser (urId row) (urEmail row)
  mtok <- liftIO (issueToken (envJwt env) au)
  tok <- maybe (throwError (toServerError TokenFailure)) pure mtok
  pure (AuthResp tok (userRowToDTO row))
