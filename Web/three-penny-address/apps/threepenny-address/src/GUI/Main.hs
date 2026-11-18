{-# LANGUAGE RecordWildCards #-}

module GUI.Main (setupGUI) where

import AddressBook.Application
  ( ContactError (..), ContactRepository (..), findContact, listContacts
  , removeContact, saveContact
  )
import           Control.Concurrent.STM      (atomically, newTVarIO, readTVarIO,
                                              writeTVar)
import           Control.Monad               (forM_, void)

import           Data.Maybe                  (fromMaybe)
import qualified Data.Text                   as T

import GUI.Components (createContactRow, formatErrors)
import GUI.Shortcuts (registerShortcuts)
import GUI.View (AddressBookView (..), createAddressBookView)
import           GUI.State                   (FormMode (..),
                                              createAppStateManager,
                                              getAppState,
                                              updateAppState)

import qualified Graphics.UI.Threepenny      as UI
import           Graphics.UI.Threepenny.Core

import GUI.AppState (AppState (..))
import AddressBook.Domain.Contact (Contact (..), ContactId)

setupGUI :: ContactRepository IO -> Window -> UI ()
setupGUI repository window = do
  void $ return window # set title "Address Book"
  stateManager <- liftIO createAppStateManager

  AddressBookView {..} <- createAddressBookView

  selectedContactVar <- liftIO $ newTVarIO (Nothing :: Maybe ContactId)
  formModeVar <- liftIO $ newTVarIO AddMode
  deleteTargetVar <- liftIO $ newTVarIO (Nothing :: Maybe ContactId)

  let refreshContactList = do
        appState <- liftIO $ getAppState stateManager
        let filteredContacts = listContacts (searchTerm appState) (appAddressBook appState)

        void $ element contactTableBody # set children []

        void $
          if null filteredContacts
            then element emptyMessage # set UI.style [("display", "block")]
            else element emptyMessage # set UI.style [("display", "none")]

        forM_ filteredContacts $ \contact -> do
          selectedId <- liftIO $ readTVarIO selectedContactVar
          let isSelected = selectedId == Just (contactId contact)
          contactRow <- createContactRow contact isSelected $ do
            liftIO $ atomically $ writeTVar selectedContactVar (Just (contactId contact))
            refreshContactList
          void $ element contactTableBody #+ [element contactRow]

  let clearForm = do
        void $ element nameInput # set UI.value ""
        void $ element phoneInput # set UI.value ""
        void $ element emailInput # set UI.value ""
        void $ element addressInput # set UI.value ""
        void $ element errorDiv # set UI.style [("display", "none")]

  let showError msg = do
        void $ element errorDiv # set text msg
        void $ element errorDiv # set UI.style [("display", "block")]

  let hideError = element errorDiv # set UI.style [("display", "none")]

  let reportError err = case err of
        ValidationFailure errors -> showError (formatErrors errors)
        ContactNotFound _ -> showError "This contact was deleted in another window."
        PersistenceFailure message ->
          void $ element persistenceError # set text message

  loaded <- liftIO (loadAddressBook repository)
  case loaded of
    Left err -> reportError err
    Right addressBook -> liftIO $ updateAppState stateManager $ \state ->
      state {appAddressBook = addressBook}

  on UI.valueChange searchInput $ \searchText -> do
    liftIO $ updateAppState stateManager $ \state -> state {searchTerm = T.pack searchText}
    void refreshContactList

  on UI.click editButton $ \_ -> do
    selectedId <- liftIO $ readTVarIO selectedContactVar
    case selectedId of
      Nothing -> return ()
      Just cid -> do
        appState <- liftIO $ getAppState stateManager
        case findContact cid (appAddressBook appState) of
          Nothing -> return ()
          Just contact -> do
            liftIO $ atomically $ writeTVar formModeVar (EditMode cid)
            void $ element nameInput # set UI.value (T.unpack $ contactName contact)
            void $ element phoneInput # set UI.value (T.unpack $ fromMaybe "" $ contactPhone contact)
            void $ element emailInput # set UI.value (T.unpack $ fromMaybe "" $ contactEmail contact)
            void $
              element addressInput # set UI.value (T.unpack $ fromMaybe "" $ contactAddress contact)
            void hideError
            void $ element formHeader # set text "Edit Contact"
            void $ element formDiv # set UI.style [("display", "block")]
            void $ element confirmDiv # set UI.style [("display", "none")]

  on UI.click saveButton $ \_ -> do
    nameVal <- T.pack <$> get UI.value nameInput
    phoneVal <- T.pack <$> get UI.value phoneInput
    emailVal <- T.pack <$> get UI.value emailInput
    addressVal <- T.pack <$> get UI.value addressInput

    formMode <- liftIO $ readTVarIO formModeVar

    let nonBlank input = if T.null (T.strip input) then Nothing else Just input
        identifier = case formMode of
          AddMode -> Nothing
          EditMode contactIdentifier -> Just contactIdentifier

    result <- liftIO $
      saveContact repository identifier nameVal (nonBlank phoneVal) (nonBlank emailVal) (nonBlank addressVal)
    case result of
      Left err -> reportError err
      Right newAddressBook -> do
        liftIO $ updateAppState stateManager $ \state -> state {appAddressBook = newAddressBook}
        void $ element persistenceError # set text ""
        void clearForm
        void $ element formDiv # set UI.style [("display", "none")]
        void refreshContactList

  on UI.click cancelButton $ \_ -> do
    void clearForm
    void $ element formDiv # set UI.style [("display", "none")]

  on UI.click confirmYesButton $ \_ -> do
    targetId <- liftIO $ readTVarIO deleteTargetVar
    case targetId of
      Nothing -> return ()
      Just cid -> do
        result <- liftIO $ removeContact repository cid
        case result of
          Left err -> reportError err
          Right newAddressBook -> do
            liftIO $ updateAppState stateManager $ \state -> state {appAddressBook = newAddressBook}
            liftIO $ atomically $ do
              writeTVar selectedContactVar Nothing
              writeTVar deleteTargetVar Nothing
            void $ element persistenceError # set text ""
            void $ element confirmDiv # set UI.style [("display", "none")]
            void refreshContactList

  on UI.click confirmNoButton $ \_ -> do
    liftIO $ atomically $ writeTVar deleteTargetVar Nothing
    void $ element confirmDiv # set UI.style [("display", "none")]

  let triggerAddContact = do
        liftIO $ atomically $ writeTVar formModeVar AddMode
        void clearForm
        void $ element formHeader # set text "Add Contact"
        void $ element formDiv # set UI.style [("display", "block")]
        void $ element confirmDiv # set UI.style [("display", "none")]

  let triggerDeleteContact = do
        selectedId <- liftIO $ readTVarIO selectedContactVar
        case selectedId of
          Nothing -> return ()
          Just cid -> do
            liftIO $ atomically $ writeTVar deleteTargetVar (Just cid)
            void $ element confirmDiv # set UI.style [("display", "block")]
            void $ element formDiv # set UI.style [("display", "none")]

  let triggerCancelOperation = do
        void clearForm
        void $ element formDiv # set UI.style [("display", "none")]
        liftIO $ atomically $ writeTVar deleteTargetVar Nothing
        void $ element confirmDiv # set UI.style [("display", "none")]

  let triggerFocusSearch = do
        runFunction $ ffi "$(%1).focus()" searchInput

  on UI.click addButton $ \_ -> triggerAddContact
  on UI.click deleteButton $ \_ -> triggerDeleteContact

  registerShortcuts container triggerAddContact triggerDeleteContact triggerCancelOperation triggerFocusSearch

  void $ getBody window #+ [element container]

  refreshContactList
