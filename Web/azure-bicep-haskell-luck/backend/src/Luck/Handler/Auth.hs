{-# LANGUAGE RecordWildCards #-}

-- | 인증/카탈로그 핸들러 (회원가입, 로그인, 로그아웃, 체크리스트 목록).
module Luck.Handler.Auth
    ( catalogH
    , loginH
    , logoutH
    , signupH
    ) where

import           Control.Monad.Except   (throwError)
import           Control.Monad.IO.Class (liftIO)
import           Control.Monad.Reader   (ask)
import           Data.UUID.V4           (nextRandom)
import           Luck.App               (AppEnv (..), AppM)
import           Luck.Auth
    ( hashPassword
    , issueToken
    , verifyPassword
    )
import           Luck.Domain.Checklist  (catalog)
import           Luck.Domain.Validation (validateSignup)
import           Luck.Error             (DomainError (..))
import           Luck.Repository.User
    ( UserRow (..)
    , getUserByEmail
    , insertUser
    )
import           Luck.Types
import           Luck.Web.Dto           (userRowToDTO)
import           Luck.Web.Error         (toServerError)

signupH :: SignupReq -> AppM AuthResp
signupH req@SignupReq {..} =
  case validateSignup req of
    Left e -> throwError (toServerError e)
    Right () -> do
      env <- ask
      mh <- liftIO (hashPassword srPassword)
      case mh of
        Nothing -> throwError (toServerError (InternalError "비밀번호 처리 중 오류가 발생했습니다."))
        Just h -> do
          uid <- liftIO nextRandom
          res <- liftIO (insertUser (envPool env) uid srEmail h srDisplayName)
          either (throwError . toServerError) (mkAuthResp env) res

loginH :: LoginReq -> AppM AuthResp
loginH LoginReq {..} = do
  env <- ask
  mrow <- liftIO (getUserByEmail (envPool env) lrEmail)
  case mrow of
    Just row | verifyPassword lrPassword (urPasswordHash row) -> mkAuthResp env row
    _ -> throwError (toServerError InvalidCredentials)

logoutH :: AppM MessageResp
logoutH = pure (MessageResp "로그아웃되었습니다. 클라이언트에서 토큰을 삭제하세요.")

catalogH :: AppM [CatalogItem]
catalogH = pure catalog

-- | 토큰 + 사용자 DTO 응답을 만든다.
mkAuthResp :: AppEnv -> UserRow -> AppM AuthResp
mkAuthResp env row = do
  let au = AuthUser (urId row) (urEmail row)
  mtok <- liftIO (issueToken (envJwt env) au)
  case mtok of
    Nothing  -> throwError (toServerError TokenFailure)
    Just tok -> pure (AuthResp tok (userRowToDTO row))
