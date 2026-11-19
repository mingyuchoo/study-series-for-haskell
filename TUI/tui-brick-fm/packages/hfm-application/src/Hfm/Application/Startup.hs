module Hfm.Application.Startup (planStartup) where

import           Hfm.Application.Error   (FileError)
import           Hfm.Application.Program
import           Hfm.Application.State

planStartup :: FilePath -> FilePath -> AppConfig -> (Int, Int) -> Program (Either FileError AppState)
planStartup left right config size = Await (CanonicalizePath left)
  (Starting (ResolvingLeftPath (StartupContext config size) right))
