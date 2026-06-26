{-# LANGUAGE RecordWildCards #-}

-- | 인증/카탈로그 핸들러 (회원가입, 로그인, 로그아웃, 체크리스트 목록).
module Luck.Handler.Auth
    ( catalogH
    , loginH
    , logoutH
    , signupH
    ) where

import           Control.Monad.Except      (throwError)
import           Control.Monad.IO.Class    (liftIO)
import           Control.Monad.Reader      (ask)
import           Data.UUID.V4              (nextRandom)
import           Luck.App                  (AppEnv (..), AppM)
import           Luck.Auth                 (hashPassword, issueToken, verifyPassword)
import           Luck.Domain.Validation    (validateSignup)
import           Luck.Error                (DomainError (..))
import           Luck.Handler.Util         (liftEither, runDB)
import           Luck.Repository.Checklist (listItems)
import           Luck.Repository.User      (UserRow (..), getUserByEmail, insertUser)
import           Luck.Types.Auth           (AuthResp (..), AuthUser (..), LoginReq (..), SignupReq (..))
import           Luck.Types.Checklist      (CatalogItem)
import           Luck.Types.Common         (MessageResp (..))
import           Luck.Web.Dto              (checklistItemToCatalog, userRowToDTO)
import           Luck.Web.Error            (toServerError)

signupH :: SignupReq -> AppM AuthResp
signupH req@SignupReq {..} = do
  liftEither (validateSignup req)
  mh <- liftIO (hashPassword srPassword)
  h <- maybe (throwError (toServerError (InternalError "비밀번호 처리 중 오류가 발생했습니다."))) pure mh
  uid <- liftIO nextRandom
  row <- liftEither =<< runDB (\p -> insertUser p uid srEmail h srDisplayName)
  mkAuthResp row

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
