module Hfm.Application.Startup (planStartup) where

import Control.Monad.Except (ExceptT (..), runExceptT)
import Hfm.Application.Ports (FileError)
import Hfm.Application.Program
import Hfm.Application.State

-- Startup follows the same port boundary as navigation; Main only assembles it.
planStartup :: FilePath -> FilePath -> AppConfig -> (Int, Int) -> Program (Either FileError AppState)
planStartup leftArg rightArg config size = runExceptT $ do
  left <- ExceptT (request (CanonicalizePath leftArg))
  right <- ExceptT (request (CanonicalizePath rightArg))
  leftEntries <- ExceptT (request (ReadEntries False left))
  rightEntries <- ExceptT (request (ReadEntries False right))
  pure (initialState left leftEntries right rightEntries config size)
