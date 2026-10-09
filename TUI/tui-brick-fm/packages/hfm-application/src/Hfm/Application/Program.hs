{-# LANGUAGE GADTs #-}

module Hfm.Application.Program
  ( FileRequest (..)
  , Program (..)
  , request
  ) where

import qualified Data.ByteString as BS
import qualified Data.Text as T
import Hfm.Application.Ports (FileError)
import Hfm.Domain.Entry (Entry)

-- Each request fixes its response type; no IO action can be embedded in a plan.
data FileRequest a where
  ReadEntries :: Bool -> FilePath -> FileRequest [Entry]
  CanonicalizePath :: FilePath -> FileRequest FilePath
  DirectoryExists :: FilePath -> FileRequest Bool
  ReadPreview :: FilePath -> FileRequest BS.ByteString
  CopyEntry :: FilePath -> FilePath -> FileRequest ()
  MoveEntry :: FilePath -> FilePath -> FileRequest ()
  DeleteEntry :: FilePath -> FileRequest ()
  MakeDirectory :: FilePath -> FileRequest ()
  EditFile :: FilePath -> FilePath -> FileRequest Int
  RunCommand :: FilePath -> T.Text -> FileRequest Int

-- Continuations allow later requests to depend on earlier results, including failure.
data Program a where
  Done :: a -> Program a
  Await :: FileRequest b -> (Either FileError b -> Program a) -> Program a

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

request :: FileRequest a -> Program (Either FileError a)
request effect = Await effect Done
