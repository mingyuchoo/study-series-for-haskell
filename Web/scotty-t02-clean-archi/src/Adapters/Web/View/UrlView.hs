{-# LANGUAGE OverloadedStrings #-}

module Adapters.Web.View.UrlView
  ( renderHomePage
  ) where

import Data.Foldable (for_)
import Data.Map (Map)
import Data.Map qualified as M
import Data.Text qualified as T
import Data.Text.Lazy qualified as LT
import Data.Time (defaultTimeLocale, formatTime)

import Domain.Entity.Url (Url (..))

import Text.Blaze.Html.Renderer.Text (renderHtml)
import Text.Blaze.Html5 qualified as H
import Text.Blaze.Html5.Attributes qualified as A

renderHomePage :: Map Int Url -> LT.Text
renderHomePage urls = renderHtml $
  H.html $ do
    H.head $ do
      H.title "URL Shortener"
      H.style $
        H.toHtml
          ( "table { border-collapse: collapse; width: 100%; } th, td { border: 1px solid #ddd; padding: 8px; text-align: left; } th { background-color: #f2f2f2; }"
              :: String
          )
    H.body $ do
      H.h1 "URL Shortener Service"
      H.form H.! A.method "post" H.! A.action "/" $ do
        H.label H.! A.for "url" $ "Enter URL to shorten:"
        H.br
        H.input
          H.! A.type_ "text"
          H.! A.name "url"
          H.! A.id "url"
          H.! A.placeholder "https://example.com"
          H.! A.style "width: 400px; padding: 5px;"
        H.br
        H.br
        H.input H.! A.type_ "submit" H.! A.value "Shorten URL" H.! A.style "padding: 5px 10px;"
      H.br
      H.h2 "Shortened URLs"
      if M.null urls
        then H.p "No URLs have been shortened yet."
        else H.table $ do
          H.thead $ H.tr $ do
            H.th "ID"
            H.th "Original URL"
            H.th "Short URL"
            H.th "Created At"
          H.tbody $
            for_ (M.toList urls) $ \(_, url) ->
              H.tr $ do
                H.td (H.toHtml $ urlId url)
                H.td $
                  H.a H.! A.href (H.textValue $ originalUrl url) H.! A.target "_blank" $
                    H.text $
                      T.take 50 (originalUrl url) <> if T.length (originalUrl url) > 50 then "..." else ""
                H.td $ H.a H.! A.href (H.textValue $ shortUrl url) $ H.text $ shortUrl url
                H.td (H.text $ T.pack $ formatTime defaultTimeLocale "%Y-%m-%d %H:%M:%S" (createdAt url))
