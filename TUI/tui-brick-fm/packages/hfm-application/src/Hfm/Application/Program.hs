{-# LANGUAGE GADTs #-}

module Hfm.Application.Program
  ( Request (..)
  , Program (..)
  , Phase (..)
  , StartupContext (..)
  , StartupStep (..)
  , TaskStep (..)
  , NavigationStep (..)
  , FileStep (..)
  , RefreshStep (..)
  , Transfer (..)
  , TransferContext (..)
  , SourceEntry (..)
  , RequestedDestination (..)
  , ProcessKind (..)
  , Lifecycle (..)
  , request
  , continue
  ) where

import qualified Data.ByteString        as BS
import qualified Data.Text              as T

import           Hfm.Application.Error  (FileError)
import           Hfm.Application.State  (AppConfig, AppState)
import           Hfm.Application.Status (Status)
import           Hfm.Domain.Config      (Settings)
import           Hfm.Domain.Entry       (Entry)

data Lifecycle = Continue | Quit
     deriving (Eq, Show)

data Transfer = CopyTransfer | MoveTransfer
     deriving (Eq, Show)

newtype SourceEntry = SourceEntry FilePath

newtype RequestedDestination = RequestedDestination FilePath

data TransferContext = TransferContext Transfer SourceEntry RequestedDestination

data ProcessKind = EditorProcess | ShellProcess
     deriving (Eq, Show)

data Request a where ReadEntries :: Bool -> FilePath -> Request [Entry]
                     CanonicalizePath :: FilePath -> Request FilePath
                     DirectoryExists :: FilePath -> Request Bool
                     ReadPreview :: FilePath -> Request BS.ByteString
                     CopyEntry :: FilePath -> FilePath -> Request ()
                     MoveEntry :: FilePath -> FilePath -> Request ()
                     DeleteEntry :: FilePath -> Request ()
                     MakeDirectory :: FilePath -> Request ()
                     EditFile :: Maybe FilePath -> FilePath -> FilePath -> Request Int
                     RunCommand :: FilePath -> T.Text -> Request Int
                     SaveSettings :: Settings -> Request ()

data StartupContext = StartupContext AppConfig (Int, Int)

data StartupStep response where ResolvingLeftPath :: StartupContext -> FilePath -> StartupStep FilePath
                                ResolvingRightPath :: StartupContext -> FilePath -> StartupStep FilePath
                                LoadingLeftEntries :: StartupContext -> FilePath -> FilePath -> StartupStep [Entry]
                                LoadingRightEntries :: StartupContext -> FilePath -> [Entry] -> FilePath -> StartupStep [Entry]

data NavigationStep response where
  ResolvingDirectory :: Maybe FilePath -> NavigationStep FilePath
  LoadingDirectory :: FilePath -> Maybe FilePath -> NavigationStep [Entry]
  InspectingLink :: FilePath -> NavigationStep Bool
  LoadingPreview :: FilePath -> NavigationStep BS.ByteString

data FileStep response where
  InspectingDestination :: TransferContext -> FileStep Bool
  CompletingMutation :: Status -> FileStep ()

data RefreshStep response where
  RefreshingLeftPanel :: RefreshStep [Entry]
  RefreshingRightPanel :: [Entry] -> RefreshStep [Entry]

data TaskStep response where
  Navigating :: NavigationStep response -> TaskStep response
  ChangingFiles :: FileStep response -> TaskStep response
  Refreshing :: Bool -> RefreshStep response -> TaskStep response
  CompletingProcess :: ProcessKind -> TaskStep Int
  PersistingSettings :: AppState -> TaskStep ()

data Phase response result where ReturningResponse :: Phase response (Either FileError response)
                                 Starting :: StartupStep response -> Phase response (Either FileError AppState)
                                 Working :: AppState -> TaskStep response -> Phase response (AppState, Lifecycle)

data Program result where Done :: result -> Program result
                          Await :: Request response -> Phase response result -> Program result

request :: Request response -> Program (Either FileError response)
request effect = Await effect ReturningResponse

continue :: AppState -> Program (AppState, Lifecycle)
continue state = Done (state, Continue)
