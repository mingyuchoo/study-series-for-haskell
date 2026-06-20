{-# LANGUAGE OverloadedStrings #-}

module Main
  ( main
  ) where

import Control.Exception (SomeException, catch)

import Data.Text qualified as T
import Data.Text.IO qualified as TIO

import Presentation.Server

import System.IO (BufferMode (NoBuffering), hSetBuffering, stdout)

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  config <- loadConfigFromEnv
  runServer config
    `catch` \e -> TIO.putStrLn $ "Error: " <> T.pack (show (e :: SomeException))
