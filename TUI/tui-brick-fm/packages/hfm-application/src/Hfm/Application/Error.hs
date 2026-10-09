module Hfm.Application.Error (FileError (..)) where

import qualified Data.Text as T

-- Adapter failures are values, independent of executable ports and OS exceptions.
data FileError = Missing | PermissionDenied | FileFailure T.Text deriving (Eq, Show)
