{-# LANGUAGE RecordWildCards #-}

module GUI.View (AddressBookView (..), createAddressBookView) where

import Control.Monad (void)
import Graphics.UI.Threepenny qualified as UI
import Graphics.UI.Threepenny.Core
import GUI.Components (createButton)

data AddressBookView = AddressBookView
  { container :: Element
  , persistenceError :: Element
  , searchInput :: Element
  , addButton :: Element
  , editButton :: Element
  , deleteButton :: Element
  , contactTableBody :: Element
  , emptyMessage :: Element
  , errorDiv :: Element
  , formHeader :: Element
  , nameInput :: Element
  , phoneInput :: Element
  , emailInput :: Element
  , addressInput :: Element
  , saveButton :: Element
  , cancelButton :: Element
  , formDiv :: Element
  , confirmYesButton :: Element
  , confirmNoButton :: Element
  , confirmDiv :: Element
  }

createAddressBookView :: UI AddressBookView
createAddressBookView = do
  persistenceError <- UI.p # set (UI.attr "role") "alert"

  container <-
    UI.div
      # set
        UI.style
        [ ("max-width", "900px")
        , ("margin", "0 auto")
        , ("padding", "20px")
        , ("font-family", "Arial, sans-serif")
        ]

  header <-
    UI.h1
      # set text "Address Book"
      # set UI.style [("text-align", "center"), ("color", "#333")]

  searchLabel <- UI.label # set text "Search contacts:"
  searchInput <-
    UI.input
      # set UI.type_ "text"
      # set (UI.attr "placeholder") "Enter name, phone, or email..."
      # set
        UI.style
        [("width", "100%"), ("padding", "8px"), ("margin", "5px 0"), ("box-sizing", "border-box")]
  searchDiv <- UI.div # set UI.style [("margin-bottom", "20px")]
  void $ element searchDiv #+ [element searchLabel, UI.br, element searchInput]

  addButton <- createButton "Add Contact" "#4CAF50"
  editButton <- createButton "Edit Contact" "#2196F3"
  deleteButton <- createButton "Delete Contact" "#f44336"
  actionDiv <- UI.div # set UI.style [("margin-bottom", "20px")]
  void $ element actionDiv #+ [element addButton, element editButton, element deleteButton]

  listHeader <- UI.h3 # set text "Contacts"
  contactTableBody <- mkElement "tbody" # set UI.style []
  contactTable <-
    UI.table
      # set
        UI.style
        [ ("width", "100%")
        , ("border-collapse", "collapse")
        , ("border", "1px solid #ddd")
        ]

  headerRow <- UI.tr
  selectHeader <-
    UI.th
      # set text ""
      # set
        UI.style
        [ ("border", "1px solid #ddd")
        , ("padding", "8px")
        , ("background-color", "#f2f2f2")
        , ("width", "40px")
        ]
  nameHeader <-
    UI.th
      # set text "Name"
      # set
        UI.style
        [("border", "1px solid #ddd"), ("padding", "8px"), ("background-color", "#f2f2f2")]
  phoneHeader <-
    UI.th
      # set text "Phone"
      # set
        UI.style
        [("border", "1px solid #ddd"), ("padding", "8px"), ("background-color", "#f2f2f2")]
  emailHeader <-
    UI.th
      # set text "Email"
      # set
        UI.style
        [("border", "1px solid #ddd"), ("padding", "8px"), ("background-color", "#f2f2f2")]
  addressHeader <-
    UI.th
      # set text "Address"
      # set
        UI.style
        [("border", "1px solid #ddd"), ("padding", "8px"), ("background-color", "#f2f2f2")]
  actionsHeader <-
    UI.th
      # set text "Actions"
      # set
        UI.style
        [ ("border", "1px solid #ddd")
        , ("padding", "8px")
        , ("background-color", "#f2f2f2")
        , ("width", "100px")
        ]

  tableHead <- mkElement "thead" # set UI.style []
  void $
    element headerRow
      #+ [ element selectHeader
         , element nameHeader
         , element phoneHeader
         , element emailHeader
         , element addressHeader
         , element actionsHeader
         ]
  void $ element tableHead #+ [element headerRow]
  void $ element contactTable #+ [element tableHead, element contactTableBody]

  emptyMessage <-
    UI.p
      # set text "No contacts found. Click 'Add Contact' to get started."
      # set UI.style [("text-align", "center"), ("color", "#666"), ("font-style", "italic")]

  listDiv <- UI.div # set UI.style [("margin-bottom", "20px")]
  void $ element listDiv #+ [element listHeader, element contactTable, element emptyMessage]

  errorDiv <-
    UI.div
      # set
        UI.style
        [ ("display", "none")
        , ("color", "#f44336")
        , ("padding", "10px")
        , ("background-color", "#ffebee")
        , ("border-radius", "4px")
        , ("margin-bottom", "10px")
        ]

  formHeader <- UI.h3 # set text "Add Contact"
  nameLabel <- UI.label # set text "Name (required):"
  nameInput <-
    UI.input
      # set UI.type_ "text"
      # set
        UI.style
        [ ("width", "100%")
        , ("padding", "8px")
        , ("margin", "5px 0 10px 0")
        , ("box-sizing", "border-box")
        ]
  phoneLabel <- UI.label # set text "Phone:"
  phoneInput <-
    UI.input
      # set UI.type_ "tel"
      # set
        UI.style
        [ ("width", "100%")
        , ("padding", "8px")
        , ("margin", "5px 0 10px 0")
        , ("box-sizing", "border-box")
        ]
  emailLabel <- UI.label # set text "Email:"
  emailInput <-
    UI.input
      # set UI.type_ "email"
      # set
        UI.style
        [ ("width", "100%")
        , ("padding", "8px")
        , ("margin", "5px 0 10px 0")
        , ("box-sizing", "border-box")
        ]
  addressLabel <- UI.label # set text "Address:"
  addressInput <-
    UI.textarea
      # set
        UI.style
        [ ("width", "100%")
        , ("padding", "8px")
        , ("margin", "5px 0 10px 0")
        , ("height", "60px")
        , ("box-sizing", "border-box")
        ]

  saveButton <- createButton "Save" "#4CAF50"
  cancelButton <- createButton "Cancel" "#666"
  buttonDiv <- UI.div
  void $ element buttonDiv #+ [element saveButton, element cancelButton]

  formDiv <-
    UI.div
      # set
        UI.style
        [ ("display", "none")
        , ("border", "1px solid #ddd")
        , ("padding", "20px")
        , ("background-color", "#f9f9f9")
        , ("border-radius", "4px")
        , ("margin-bottom", "20px")
        ]
  void $
    element formDiv
      #+ [ element formHeader
         , element errorDiv
         , element nameLabel
         , UI.br
         , element nameInput
         , element phoneLabel
         , UI.br
         , element phoneInput
         , element emailLabel
         , UI.br
         , element emailInput
         , element addressLabel
         , UI.br
         , element addressInput
         , element buttonDiv
         ]

  confirmHeader <- UI.h3 # set text "Confirm Delete"
  confirmMessage <- UI.p # set text "Are you sure you want to delete this contact?"
  confirmYesButton <- createButton "Yes, Delete" "#f44336"
  confirmNoButton <- createButton "Cancel" "#666"
  confirmButtonDiv <- UI.div
  void $ element confirmButtonDiv #+ [element confirmYesButton, element confirmNoButton]

  confirmDiv <-
    UI.div
      # set
        UI.style
        [ ("display", "none")
        , ("border", "1px solid #ddd")
        , ("padding", "20px")
        , ("background-color", "#fff3e0")
        , ("border-radius", "4px")
        , ("margin-bottom", "20px")
        ]
  void $
    element confirmDiv
      #+ [element confirmHeader, element confirmMessage, element confirmButtonDiv]

  void $
    element container
      #+ [ element header
         , element persistenceError
         , element searchDiv
         , element actionDiv
         , element formDiv
         , element confirmDiv
         , element listDiv
         ]
  pure AddressBookView {..}
