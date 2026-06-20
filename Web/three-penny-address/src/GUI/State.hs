module GUI.State
    ( AppStateManager (..)
    , FormMode (..)
    , createAppStateManager
    , getAppState
    , setAppState
    , updateAppState
    ) where

import           Control.Concurrent.STM  (TVar, atomically, newTVarIO, readTVar,
                                          readTVarIO, writeTVar)

import qualified Data.Text               as T

import           Models.AddressBookState (emptyAddressBookState)
import           Models.AppState         (AppState (..))
import           Models.Contact          (ContactId)

-- | Form mode: Add or Edit.
data FormMode = AddMode
              | EditMode ContactId
     deriving (Eq, Show)

-- | Application state manager using TVar for thread-safe state management.
data AppStateManager = AppStateManager { appStateTVar :: TVar AppState
                                       }

-- | Create a new application state manager with initial empty state.
createAppStateManager :: IO AppStateManager
createAppStateManager = do
  let initialState =
        AppState
          { appAddressBook = emptyAddressBookState
          , searchTerm = T.empty
          }
  tvar <- newTVarIO initialState
  return $ AppStateManager tvar

-- | Update the application state using STM.
updateAppState :: AppStateManager -> (AppState -> AppState) -> IO ()
updateAppState (AppStateManager tvar) updateFn =
  atomically $ do
    currentState <- readTVar tvar
    writeTVar tvar (updateFn currentState)

-- | Get the current application state.
getAppState :: AppStateManager -> IO AppState
getAppState (AppStateManager tvar) = readTVarIO tvar

-- | Set the application state directly.
setAppState :: AppStateManager -> AppState -> IO ()
setAppState (AppStateManager tvar) newState =
  atomically $ writeTVar tvar newState
