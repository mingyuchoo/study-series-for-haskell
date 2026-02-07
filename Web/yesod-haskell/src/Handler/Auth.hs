{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes       #-}
{-# LANGUAGE TemplateHaskell   #-}

-- | [REQ-F002] 인증 핸들러 — 회원가입, 로그인, 로그아웃
module Handler.Auth where

import Import
import Service.AuthService (hashPassword, verifyPassword)

-- | 회원가입 폼 표시
getRegisterR :: HandlerFor App Html
getRegisterR = defaultLayout $ do
    setTitle "회원가입"
    toWidget $(hamletFile "templates/auth/register.hamlet")

-- | 회원가입 처리
postRegisterR :: HandlerFor App Html
postRegisterR = do
    name  <- runInputPost $ ireq textField "name"
    email <- runInputPost $ ireq textField "email"
    pw    <- runInputPost $ ireq textField "password"

    -- 이메일 중복 확인
    mExisting <- runDB $ getBy (UniqueEmail email)
    case mExisting of
        Just _  -> do
            setMessage "이미 등록된 이메일입니다."
            redirect RegisterR
        Nothing -> do
            mHashed <- liftIO $ hashPassword pw
            case mHashed of
                Nothing -> do
                    setMessage "비밀번호 처리 중 오류가 발생했습니다."
                    redirect RegisterR
                Just hashed -> do
                    now <- liftIO getCurrentTime
                    uid <- runDB $ insert $ User name email hashed now
                    setSession "userId" (toPathPiece uid)
                    setSession "userName" name
                    setMessage "회원가입이 완료되었습니다."
                    redirect HomeR

-- | 로그인 폼 표시
getLoginR :: HandlerFor App Html
getLoginR = defaultLayout $ do
    setTitle "로그인"
    toWidget $(hamletFile "templates/auth/login.hamlet")

-- | 로그인 처리
postLoginR :: HandlerFor App Html
postLoginR = do
    email <- runInputPost $ ireq textField "email"
    pw    <- runInputPost $ ireq textField "password"

    mUser <- runDB $ getBy (UniqueEmail email)
    case mUser of
        Nothing -> do
            setMessage "이메일 또는 비밀번호가 올바르지 않습니다."
            redirect LoginR
        Just (Entity uid user) ->
            if verifyPassword pw (userPasswordHash user)
                then do
                    setSession "userId" (toPathPiece uid)
                    setSession "userName" (userName user)
                    setMessage "로그인되었습니다."
                    redirect HomeR
                else do
                    setMessage "이메일 또는 비밀번호가 올바르지 않습니다."
                    redirect LoginR

-- | 로그아웃 처리
postLogoutR :: HandlerFor App Html
postLogoutR = do
    deleteSession "userId"
    deleteSession "userName"
    setMessage "로그아웃되었습니다."
    redirect HomeR
