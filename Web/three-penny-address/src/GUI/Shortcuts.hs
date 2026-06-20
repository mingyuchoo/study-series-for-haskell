module GUI.Shortcuts
    ( KeyboardShortcut (..)
    , handleKeyboardShortcut
    , parseKeyboardShortcut
    ) where

-- | Keyboard shortcuts supported by the application.
data KeyboardShortcut = NewContact | DeleteContact | CancelOperation | FocusSearch
     deriving (Eq, Show)

-- | Handle a keyboard shortcut and return the corresponding action name.
handleKeyboardShortcut :: KeyboardShortcut -> String
handleKeyboardShortcut NewContact      = "new-contact"
handleKeyboardShortcut DeleteContact   = "delete-contact"
handleKeyboardShortcut CancelOperation = "cancel-operation"
handleKeyboardShortcut FocusSearch     = "focus-search"

-- | Parse keyboard event data into a KeyboardShortcut.
parseKeyboardShortcut :: Int -> Bool -> Maybe KeyboardShortcut
parseKeyboardShortcut keyCode ctrlKey
  | ctrlKey && keyCode == 78 = Just NewContact
  | ctrlKey && keyCode == 70 = Just FocusSearch
  | keyCode == 46 = Just DeleteContact
  | keyCode == 27 = Just CancelOperation
  | otherwise = Nothing
