{-# LANGUAGE OverloadedStrings #-}

module Shared.Error (
    internalErrorMessage,
) where

import Data.Text (Text)

internalErrorMessage :: Text
internalErrorMessage = "Internal server error"
