{-# LANGUAGE GADTs #-}

module Hfm.Application.Startup (planStartup, resumeStartup) where

import           Hfm.Application.Error   (FileError)
import           Hfm.Application.Program
import           Hfm.Application.State

planStartup :: FilePath -> FilePath -> AppConfig -> (Int, Int) -> Program (Either FileError AppState)
planStartup left right config size = Await (CanonicalizePath left)
  (Starting (ResolvingLeftPath (StartupContext config size) right))

resumeStartup :: StartupStep response -> Either FileError response -> Program (Either FileError AppState)
resumeStartup _ (Left err) = Done (Left err)
resumeStartup (ResolvingLeftPath context rightArg) (Right left) =
  Await (CanonicalizePath rightArg) (Starting (ResolvingRightPath context left))
resumeStartup (ResolvingRightPath context left) (Right right) =
  Await (ReadEntries False left) (Starting (LoadingLeftEntries context left right))
resumeStartup (LoadingLeftEntries context left right) (Right leftEntries) =
  Await (ReadEntries False right) (Starting (LoadingRightEntries context left leftEntries right))
resumeStartup (LoadingRightEntries (StartupContext config size) left leftEntries right) (Right rightEntries) =
  Done (Right (initialState left leftEntries right rightEntries config size))
