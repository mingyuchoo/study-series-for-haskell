{-# LANGUAGE OverloadedStrings #-}

module Lib
  ( shortener
  ) where

import Control.Monad.IO.Class (MonadIO (liftIO))

import Data.Foldable (for_)
import Data.IORef (modifyIORef, newIORef, readIORef)
import Data.Map (Map)
import Data.Map qualified as M
import Data.Text (Text)
import Data.Text.Lazy qualified as LT

import Network.HTTP.Types (status404)

import Text.Blaze.Html.Renderer.Text (renderHtml)
import Text.Blaze.Html5 qualified as H
import Text.Blaze.Html5.Attributes qualified as A

import Web.Scotty

-- | shortener
shortener :: IO ()
shortener = do
  urlsR <- newIORef (1 :: Int, mempty :: Map Int Text)
  scotty 4000 $ do
    get "/" $ do
      (_, urls) <- liftIO $ readIORef urlsR
      html $
        renderHtml $
          H.html $
            H.body $ do
              H.h1 "Shortener"
              H.form H.! A.method "post" H.! A.action "/" $ do
                H.input H.! A.type_ "text" H.! A.name "url"
                H.input H.! A.type_ "submit"
              H.table $
                for_ (M.toList urls) $ \(i, url) ->
                  H.tr $ do
                    H.td (H.toHtml i)
                    H.td (H.text url)
    post "/" $ do
      url <- param "url"
      liftIO $
        modifyIORef urlsR $
          \(i, urls) ->
            (i + 1, M.insert i url urls)
      redirect "/"
    get "/:n" $ do
      n <- param "n"
      (_, urls) <- liftIO $ readIORef urlsR
      case M.lookup n urls of
        Just url -> redirect (LT.fromStrict url)
        Nothing  -> raiseStatus status404 "not found"
