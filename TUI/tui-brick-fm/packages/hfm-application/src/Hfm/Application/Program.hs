{-# LANGUAGE GADTs #-}

module Hfm.Application.Program
  ( Request (..)
  , Program (..)
  , request
  ) where

import qualified Data.ByteString as BS
import qualified Data.Text as T
import Hfm.Application.Error (FileError)
import Hfm.Domain.Entry (Entry)

-- Each request fixes its response type; no IO action can be embedded in a plan.
data Request a where
  ReadEntries :: Bool -> FilePath -> Request [Entry]
  CanonicalizePath :: FilePath -> Request FilePath
  DirectoryExists :: FilePath -> Request Bool
  ReadPreview :: FilePath -> Request BS.ByteString
  CopyEntry :: FilePath -> FilePath -> Request ()
  MoveEntry :: FilePath -> FilePath -> Request ()
  DeleteEntry :: FilePath -> Request ()
  MakeDirectory :: FilePath -> Request ()
  EditFile :: Maybe FilePath -> FilePath -> FilePath -> Request Int
  RunCommand :: FilePath -> T.Text -> Request Int

-- Continuations allow later requests to depend on earlier results, including failure.
data Program a where
  Done :: a -> Program a
  Await :: Request b -> (Either FileError b -> Program a) -> Program a

instance Functor Program where
  fmap f program = program >>= pure . f

instance Applicative Program where
  pure = Done
  functions <*> values = do
    f <- functions
    fmap f values

instance Monad Program where
  Done value >>= next = next value
  Await effect resume >>= next = Await effect (\result -> resume result >>= next)

request :: Request a -> Program (Either FileError a)
request effect = Await effect Done
