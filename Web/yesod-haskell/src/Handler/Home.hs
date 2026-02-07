{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes       #-}
{-# LANGUAGE TemplateHaskell   #-}

-- | [REQ-F001] 홈 페이지 핸들러
module Handler.Home where

import Import

-- | 홈 페이지 — 최신 포스트 목록 표시
getHomeR :: HandlerFor App Html
getHomeR = do
    posts <- runDB $ selectList [] [Desc PostCreatedAt, LimitTo 10]
    authors <- runDB $ mapM (\(Entity _ p) -> get (postAuthorId p)) posts
    let postsWithAuthors = zip posts authors
    defaultLayout $ do
        setTitle "블로그 홈"
        toWidget $(hamletFile "templates/home.hamlet")
