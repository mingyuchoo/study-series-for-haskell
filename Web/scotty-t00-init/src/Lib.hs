{-# LANGUAGE OverloadedStrings #-}

module Lib
  ( someFunc
  ) where

import Web.Scotty

-- | render "Hello, World!"
someFunc :: IO ()
someFunc =
  scotty 4000 $
    get "/" $
      html "<h1>Hello, World!</h1>"
