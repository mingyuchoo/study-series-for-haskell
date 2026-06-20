module GUI.Components
    ( ContactForm (..)
    , UIComponents (..)
    , createButton
    , createContactRow
    , formatErrors
    ) where

import           Control.Concurrent.STM      (TVar, atomically, writeTVar)
import           Control.Monad               (void, when)
import           Control.Monad.IO.Class      (liftIO)

import           Data.Maybe                  (fromMaybe)
import qualified Data.Text                   as T

import qualified Graphics.UI.Threepenny      as UI
import           Graphics.UI.Threepenny.Core (Element, UI, element, on, set,
                                              text, (#), (#+))

import           Models.Contact              (Contact (..), ContactId)

import           Services.ValidationService  (ValidationError (..))

-- | Main UI components
data UIComponents = UIComponents { contactList  :: Element
                                 , searchInput  :: Element
                                 , addButton    :: Element
                                 , editButton   :: Element
                                 , deleteButton :: Element
                                 , contactForm  :: ContactForm
                                 }

-- | Contact form components
data ContactForm = ContactForm { nameInput    :: Element
                               , phoneInput   :: Element
                               , emailInput   :: Element
                               , addressInput :: Element
                               , saveButton   :: Element
                               , cancelButton :: Element
                               }

-- | Create a styled button.
createButton :: String -> String -> UI Element
createButton label bgColor =
  UI.button
    # set text label
    # set
      UI.style
      [ ("background-color", bgColor)
      , ("color", "white")
      , ("padding", "10px 20px")
      , ("border", "none")
      , ("border-radius", "4px")
      , ("cursor", "pointer")
      , ("margin-right", "10px")
      ]

-- | Create a contact row with selection support.
createContactRow :: Contact -> Bool -> TVar (Maybe ContactId) -> UI () -> UI Element
createContactRow contact isSelected selectedVar refreshList = do
  let bgColor = if isSelected then "#e3f2fd" else "white"

  row <- UI.tr # set UI.style [("background-color", bgColor), ("cursor", "pointer")]

  radioBtn <-
    UI.input
      # set UI.type_ "radio"
      # set (UI.attr "name") "contact-select"
  when isSelected $ void $ element radioBtn # set (UI.attr "checked") "checked"

  selectCell <-
    UI.td
      # set UI.style [("border", "1px solid #ddd"), ("padding", "8px"), ("text-align", "center")]
  void $ element selectCell #+ [element radioBtn]

  nameCell <-
    UI.td
      # set text (T.unpack $ contactName contact)
      # set UI.style [("border", "1px solid #ddd"), ("padding", "8px")]
  phoneCell <-
    UI.td
      # set text (T.unpack $ fromMaybe "" $ contactPhone contact)
      # set UI.style [("border", "1px solid #ddd"), ("padding", "8px")]
  emailCell <-
    UI.td
      # set text (T.unpack $ fromMaybe "" $ contactEmail contact)
      # set UI.style [("border", "1px solid #ddd"), ("padding", "8px")]
  addressCell <-
    UI.td
      # set text (T.unpack $ fromMaybe "" $ contactAddress contact)
      # set UI.style [("border", "1px solid #ddd"), ("padding", "8px")]

  deleteBtn <-
    UI.button
      # set text "x"
      # set
        UI.style
        [ ("background-color", "#f44336")
        , ("color", "white")
        , ("border", "none")
        , ("border-radius", "4px")
        , ("cursor", "pointer")
        , ("padding", "5px 10px")
        , ("font-size", "14px")
        ]
  actionsCell <-
    UI.td
      # set UI.style [("border", "1px solid #ddd"), ("padding", "8px"), ("text-align", "center")]
  void $ element actionsCell #+ [element deleteBtn]

  void $
    element row
      #+ [ element selectCell
         , element nameCell
         , element phoneCell
         , element emailCell
         , element addressCell
         , element actionsCell
         ]

  on UI.click row $ \_ -> do
    liftIO $ atomically $ writeTVar selectedVar (Just $ contactId contact)
    refreshList

  on UI.click radioBtn $ \_ -> do
    liftIO $ atomically $ writeTVar selectedVar (Just $ contactId contact)
    refreshList

  return row

-- | Format validation errors for display.
formatErrors :: [ValidationError] -> String
formatErrors errors = unlines $ map formatError errors
  where
    formatError EmptyName = "Name is required and cannot be empty."
    formatError InvalidEmail = "Invalid email format."
    formatError InvalidPhone = "Invalid phone number format. Use only digits, spaces, hyphens, and parentheses."
