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

-- | 인증번호 유효시간 (초). 콘솔로 받은 6자리를 이 시간 안에 입력해야 한다.
verificationTtlSeconds :: Num a => a
verificationTtlSeconds = 5 * 60

-- | 1단계: 가입 정보를 검증하고 인증번호를 발급한다.
--   비밀번호 해시·이름을 인증 대기 테이블에 임시 저장하고, 6자리 코드를
--   생성해 콘솔에 출력한다 (이메일 연동 전까지의 임시 전달 경로). 토큰은 아직 없다.
signupRequestH :: SignupReq -> AppM MessageResp
signupRequestH req@SignupReq {..} = do
  liftEither (validateSignup req)
  let email = T.strip srEmail
  existing <- runDB (\p -> getUserByEmail p email)
  when (maybe False (const True) existing) $
    throwError (toServerError EmailTaken)
  mh <- liftIO (hashPassword srPassword)
  h <- maybe (throwError (toServerError (InternalError "비밀번호 처리 중 오류가 발생했습니다."))) pure mh
  code <- liftIO genVerificationCode
  now <- liftIO getCurrentTime
  let expiresAt = addUTCTime verificationTtlSeconds now
  runDB (\p -> upsertVerification p email h srDisplayName code expiresAt)
  liftIO $
    putStrLn
      ("[SIGNUP] verification code for "
         <> T.unpack email
         <> ": "
         <> T.unpack code
         <> " (expires in 5m)")
  pure (MessageResp "인증번호를 발송했습니다. 콘솔 로그의 6자리 번호를 입력하세요.")

-- | 2단계: 인증번호를 확인하고 실제 사용자를 생성한다.
--   코드 일치 + 미만료면 'insertUser' 로 승격하고 토큰을 발급한 뒤 대기 행을 삭제한다.
signupVerifyH :: VerifyReq -> AppM AuthResp
signupVerifyH VerifyReq {..} = do
  let email = T.strip veEmail
      badCode = ValidationError "인증번호가 올바르지 않거나 만료되었습니다."
  mrow <- runDB (\p -> getVerification p email)
  row <- maybe (throwError (toServerError badCode)) pure mrow
  now <- liftIO getCurrentTime
  when (vrCode row /= T.strip veCode || vrExpiresAt row < now) $
    throwError (toServerError badCode)
  uid <- liftIO nextRandom
  admins <- cfgAdminEmails . envConfig <$> ask
  let emailIsAdmin = T.toLower (vrEmail row) `elem` admins
      firstUserFallback = null admins
  inserted <-
    liftEither
      =<< runDB
        (\p -> insertUser p uid (vrEmail row) (vrPasswordHash row) (vrDisplayName row) emailIsAdmin firstUserFallback)
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
