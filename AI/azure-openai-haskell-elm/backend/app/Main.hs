{-# LANGUAGE OverloadedStrings #-}

module Main
  ( main
  ) where

import Control.Exception (SomeException, catch)
import Control.Monad (join)

import Data.Text qualified as T
import Data.Text.IO qualified as TIO

import Flow ((|>))

import Presentation.Server

main :: IO ()
main =
  loadConfigFromEnv
    |> fmap runServer
    |> join
    |> flip catch (\e -> ("Error: " <> T.pack (show (e :: SomeException))) |> TIO.putStrLn)
