{-# LANGUAGE InstanceSigs          #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE QuasiQuotes           #-}
{-# LANGUAGE TemplateHaskell       #-}
{-# LANGUAGE TypeFamilies          #-}

-- | [REQ-F001] App 타입 및 Yesod 인스턴스 정의
module Foundation
  where

import Data.Text (Text)
import Database.Persist.Sql (ConnectionPool, SqlBackend, SqlPersistT, runSqlPool)
import Model
import Settings
import Text.Hamlet (hamletFile)
import Yesod.Core
import Yesod.Form (FormMessage, defaultFormMessage)
import Yesod.Persist

-- | 애플리케이션 타입
data App = App
  { appSettings       :: AppSettings
  , appConnectionPool :: ConnectionPool
  }

mkYesodData "App" $(parseRoutesFile "config/routes.yesodroutes")

instance Yesod App where
  defaultLayout :: WidgetFor App () -> HandlerFor App Html
  defaultLayout widget = do
    pc <- widgetToPageContent widget
    muser <- lookupSession "userName"
    mmsg <- getMessage
    withUrlRenderer $(hamletFile "templates/default-layout.hamlet")

  makeSessionBackend :: App -> IO (Maybe SessionBackend)
  makeSessionBackend _ =
    Just <$> defaultClientSessionBackend 120 "config/client_session_key.aes"

instance RenderMessage App FormMessage where
  renderMessage _ _ = defaultFormMessage

instance YesodPersist App where
  type YesodPersistBackend App = SqlBackend
  runDB :: SqlPersistT (HandlerFor App) a -> HandlerFor App a
  runDB action = do
    app <- getYesod
    runSqlPool action (appConnectionPool app)

-- | 현재 로그인한 사용자 ID를 세션에서 가져오기
maybeAuthId :: HandlerFor App (Maybe UserId)
maybeAuthId = do
  mUid <- lookupSession "userId"
  return $ mUid >>= fromPathPiece

-- | 로그인 필수 — 미인증 시 로그인 페이지로 리다이렉트
requireAuthId :: HandlerFor App UserId
requireAuthId = do
  mUid <- maybeAuthId
  case mUid of
    Nothing  -> redirect LoginR
    Just uid -> return uid

-- | 로그인한 사용자의 Entity를 가져오기
requireAuth :: HandlerFor App (Entity User)
requireAuth = do
  uid <- requireAuthId
  mUser <- runDB $ get uid
  case mUser of
    Nothing   -> redirect LoginR
    Just user -> return (Entity uid user)
