module Hfm.Application.Internal.Action (Action, halt, attempt) where

import Control.Monad.Except (ExceptT, throwError)
import Control.Monad.State.Strict (StateT, modify)
import Control.Monad.Trans.Class (lift)
import Hfm.Application.Ports (FileError)
import Hfm.Application.Program (Program)
import Hfm.Application.State (AppState (..))
import Hfm.Application.Status (Status (Failed))

type Action = ExceptT () (StateT AppState Program)

halt :: Action ()
halt = throwError ()

attempt :: Program (Either FileError a) -> (a -> Action ()) -> Action ()
attempt program onSuccess = do
  result <- lift (lift program)
  case result of
    Left err -> modify (\s -> s { stStatus = Failed err })
    Right value -> onSuccess value
