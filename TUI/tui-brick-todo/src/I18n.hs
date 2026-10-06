{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Internationalization support (MIXED: Pure + Effectful)
--
-- This module provides multi-language support for the application.
--
-- Pure components:
--   - Data types: Language, I18nMessages, UIMessages, etc.
--   - defaultMessages: Default English messages
--
-- Effectful functions:
--   - loadMessages: Load messages from YAML file (IO)
--
-- Effects:
--   - File system access (doesFileExist, readFile)
--   - YAML parsing
--   - Console output (putStrLn)
module I18n
    ( FieldLabels (..)
    , HelpMessages (..)
    , I18nMessages (..)
    , Language (..)
    , ListMessages (..)
    , SampleTodos (..)
    , StatusMessages (..)
    , SystemMessages (..)
    , UIMessages (..)
    , defaultMessages
    , loadMessages
    , stringToLanguage
    ) where

import           Data.Aeson       (FromJSON)
import qualified Data.ByteString  as BS
import qualified Data.Yaml        as Yaml

import           Flow             ((<|))

import           GHC.Generics     (Generic)

import           System.Directory (doesFileExist)
import           System.FilePath  ((</>))

-- | Supported languages (Pure)
data Language = English | Korean
     deriving (Eq, Generic, Show)

-- | Parse language from string (Pure)
stringToLanguage :: String -> Language
stringToLanguage "en"      = English
stringToLanguage "english" = English
stringToLanguage "ko"      = Korean
stringToLanguage "korean"  = Korean
stringToLanguage _         = Korean

-- | UI messages structure (Pure)
data UIMessages = UIMessages { header            :: !String
                             , todos_title       :: !String
                             , detail_title      :: !String
                             , detail_edit_title :: !String
                             , detail_add_title  :: !String
                             , no_todos          :: !String
                             , no_selection      :: !String
                             , not_found         :: !String
                             }
     deriving (Generic, Show)

instance FromJSON UIMessages

-- | Field labels (Pure)
data FieldLabels = FieldLabels { id_label              :: !String
                               , status_label          :: !String
                               , action_label          :: !String
                               , action_required_label :: !String
                               , subject_label         :: !String
                               , indirect_object_label :: !String
                               , direct_object_label   :: !String
                               , created_at_label      :: !String
                               , completed_at_label    :: !String
                               , status_changed_label  :: !String
                               , auto_generated_label  :: !String
                               }
     deriving (Generic, Show)

instance FromJSON FieldLabels

-- | Status messages (Pure)
data StatusMessages = StatusMessages { registered  :: !String
                                     , in_progress :: !String
                                     , cancelled   :: !String
                                     , completed   :: !String
                                     }
     deriving (Generic, Show)

instance FromJSON StatusMessages

-- | List display messages (Pure)
data ListMessages = ListMessages { checkbox_done    :: !String
                                 , checkbox_todo    :: !String
                                 , field_separator  :: !String
                                 , field_action     :: !String
                                 , field_subject    :: !String
                                 , field_indirect   :: !String
                                 , field_direct     :: !String
                                 , completed_prefix :: !String
                                 , created_prefix   :: !String
                                 }
     deriving (Generic, Show)

instance FromJSON ListMessages

-- | Help messages (Pure)
data HelpMessages = HelpMessages { view_mode  :: !String
                                 , edit_mode  :: !String
                                 , input_mode :: !String
                                 , add        :: !String
                                 , edit       :: !String
                                 , toggle     :: !String
                                 , delete     :: !String
                                 , navigate   :: !String
                                 , quit       :: !String
                                 }
     deriving (Generic, Show)

instance FromJSON HelpMessages

-- | System messages (Pure)
data SystemMessages = SystemMessages { config_not_found   :: !String
                                     , config_load_failed :: !String
                                     , config_loaded      :: !String
                                     , using_default      :: !String
                                     , i18n_not_found     :: !String
                                     , i18n_load_failed   :: !String
                                     , i18n_loaded        :: !String
                                     , using_default_lang :: !String
                                     }
     deriving (Generic, Show)

instance FromJSON SystemMessages

-- | Sample todos (Pure)
data SampleTodos = SampleTodos { welcome     :: !String
                               , add_hint    :: !String
                               , toggle_hint :: !String
                               }
     deriving (Generic, Show)

instance FromJSON SampleTodos

-- | Complete internationalization messages (Pure)
data I18nMessages = I18nMessages { language     :: !String
                                 , ui           :: !UIMessages
                                 , fields       :: !FieldLabels
                                 , status       :: !StatusMessages
                                 , list         :: !ListMessages
                                 , help         :: !HelpMessages
                                 , messages     :: !SystemMessages
                                 , sample_todos :: !SampleTodos
                                 }
     deriving (Generic, Show)

instance FromJSON I18nMessages

-- | Default English messages (Pure)
defaultMessages :: I18nMessages
defaultMessages =
  I18nMessages
    { language = "en",
      ui =
        UIMessages
          { header = "📝 Todo Manager",
            todos_title = " Todos ",
            detail_title = " Details ",
            detail_edit_title = " Details (Edit Mode - Tab: Next Field, Enter: Save, Esc: Cancel) ",
            detail_add_title = " Add New Todo (Tab: Next Field, Enter: Save, Esc: Cancel) ",
            no_todos = "No todos yet. Press 'a' to add one!",
            no_selection = "No todo selected",
            not_found = "Item to edit not found"
          },
      fields =
        FieldLabels
          { id_label = "ID",
            status_label = "Status",
            action_label = "Action",
            action_required_label = "Action (required)",
            subject_label = "Subject",
            indirect_object_label = "Indirect Object",
            direct_object_label = "Direct Object",
            created_at_label = "Created At",
            completed_at_label = "Completed At",
            status_changed_label = "Status Changed",
            auto_generated_label = "(auto-generated)"
          },
      status =
        StatusMessages
          { registered = "□ Registered",
            in_progress = "○ In Progress",
            cancelled = "✗ Cancelled",
            completed = "✓ Completed"
          },
      list =
        ListMessages
          { checkbox_done = "[✓] ",
            checkbox_todo = "[ ] ",
            field_separator = " | ",
            field_action = "Action",
            field_subject = "Subject",
            field_indirect = "Indirect",
            field_direct = "Direct",
            completed_prefix = "Done: ",
            created_prefix = "Created: "
          },
      help =
        HelpMessages
          { view_mode = "Tab: Next Field | Enter: Save | Esc: Cancel",
            edit_mode = "Tab: Next Field | Enter: Save | Esc: Cancel",
            input_mode = "Tab: Next Field | Enter: Save | Esc: Cancel",
            add = "Add",
            edit = "Edit",
            toggle = "Toggle",
            delete = "Delete",
            navigate = "Navigate",
            quit = "Quit"
          },
      messages =
        SystemMessages
          { config_not_found = "Configuration file not found",
            config_load_failed = "Failed to load keybindings configuration",
            config_loaded = "Keybindings configuration loaded.",
            using_default = "Using default keybindings.",
            i18n_not_found = "Internationalization file not found",
            i18n_load_failed = "Failed to load internationalization file",
            i18n_loaded = "Internationalization settings loaded.",
            using_default_lang = "Using default language (English)."
          },
      sample_todos =
        SampleTodos
          { welcome = "Welcome to Todo Manager!",
            add_hint = "Press 'a' to add a new todo",
            toggle_hint = "Press Space to toggle completion"
          }
    }

-- | Load messages from config directory (Effectful)
loadMessages :: FilePath -> Language -> IO I18nMessages
loadMessages configDir lang = do
  let filename = case lang of
        English -> "messages-en.yaml"
        Korean  -> "messages-ko.yaml"
      path = configDir </> filename
  exists <- doesFileExist path
  if exists
    then loadFromFile path
    else useDefault <| i18n_not_found (messages defaultMessages) <> ": " <> path
  where
    loadFromFile path = do
      content <- BS.readFile path
      case Yaml.decodeEither' content of
        Left err -> useDefault <| i18n_load_failed (messages defaultMessages) <> ": " <> show err
        Right msgs -> do
          putStrLn <| i18n_loaded (messages msgs)
          pure msgs

    useDefault msg = do
      putStrLn msg
      putStrLn <| using_default_lang (messages defaultMessages)
      pure defaultMessages
