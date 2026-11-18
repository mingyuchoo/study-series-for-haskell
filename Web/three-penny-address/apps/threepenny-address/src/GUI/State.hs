module GUI.State
    ( AppStateManager (..)
    , FormMode (..)
    , createAppStateManager
    , getAppState
    , updateAppState
    ) where

import           Control.Concurrent.STM  (TVar, atomically, newTVarIO, readTVar,
                                          readTVarIO, writeTVar)

import qualified Data.Text               as T

import           AddressBook.Domain.State (emptyAddressBookState)
import           GUI.AppState         (AppState (..))
import           AddressBook.Domain.Contact          (ContactId)

data FormMode = AddMode
              | EditMode ContactId
     deriving (Eq, Show)

data AppStateManager = AppStateManager { appStateTVar :: TVar AppState
                                       }

createAppStateManager :: IO AppStateManager
createAppStateManager = do
  let initialState =
        AppState
          { appAddressBook = emptyAddressBookState
          , searchTerm = T.empty
          }
  tvar <- newTVarIO initialState
  return $ AppStateManager tvar

updateAppState :: AppStateManager -> (AppState -> AppState) -> IO ()
updateAppState (AppStateManager tvar) updateFn =
  atomically $ do
    currentState <- readTVar tvar
    writeTVar tvar (updateFn currentState)

getAppState :: AppStateManager -> IO AppState
getAppState (AppStateManager tvar) = readTVarIO tvar
