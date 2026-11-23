module Hfm.Application.Internal.Settings ( persistSettings, resumeSettings, themePickerEvent
  , startEditorPrompt, confirmEditor
  ) where

import qualified Data.Text              as T

import           Hfm.Application.Error (FileError)
import           Hfm.Application.Program
import           Hfm.Application.State
import           Hfm.Application.Status
import           Hfm.Domain.Config      (Settings (..), validEditor)
import           Hfm.Domain.Input
import           Hfm.Domain.Selection   (selectAt, selectStep, selectedElement)

persistSettings :: AppState -> AppState -> Program (AppState, Lifecycle)
persistSettings previous updated = Await (SaveSettings (currentSettings updated))
  (Working updated (PersistingSettings previous))

resumeSettings :: AppState -> AppState -> Either FileError () -> Program (AppState, Lifecycle)
resumeSettings _ updated (Right ()) = continue updated
resumeSettings previous updated (Left err) =
  continue ((applySettings (currentSettings previous) updated)
    { stMode = stMode previous
    , stInputCursor = stInputCursor previous
    , stThemePicker = stThemePicker previous
    , stStatus = SettingsSaveFailed err
    })

themePickerEvent :: Input -> AppState -> Program (AppState, Lifecycle)
themePickerEvent event state = case event of
  KeyPress KEsc [] -> continue (state { stThemePicker = Nothing })
  KeyPress KEnter [] -> case stThemePicker state >>= selectedElement of
    Just (_, theme) ->
      let updated = state { stTheme = theme, stThemePicker = Nothing }
      in if theme == stTheme state then continue updated else persistSettings state updated
    Nothing -> continue state
  KeyPress KUp [] -> selectTheme (selectStep (-1))
  KeyPress KDown [] -> selectTheme (selectStep 1)
  KeyPress (KChar 'p') [MCtrl] -> selectTheme (selectStep (-1))
  KeyPress (KChar 'n') [MCtrl] -> selectTheme (selectStep 1)
  KeyPress KHome [] -> selectTheme (selectAt 0)
  KeyPress KEnd [] -> selectTheme (selectAt (-1))
  KeyPress (KChar '<') [MMeta] -> selectTheme (selectAt 0)
  KeyPress (KChar '>') [MMeta] -> selectTheme (selectAt (-1))
  KeyPress (KChar digit) [] | digit >= '1' && digit <= '8' -> selectTheme (selectAt (fromEnum digit - fromEnum '1'))
  _ -> continue state
  where
    selectTheme change = continue (state { stThemePicker = change <$> stThemePicker state })

startEditorPrompt :: AppState -> AppState
startEditorPrompt state =
  let value = maybe "" T.pack (settingsEditor (currentSettings state))
  in state { stMode = EditorPrompt value, stInputCursor = T.length value, stKeySequence = DirectInput }

confirmEditor :: T.Text -> AppState -> Program (AppState, Lifecycle)
confirmEditor value state
  | not (validEditor value) = continue (state { stStatus = InvalidEditor })
  | otherwise =
      let executable = T.strip value
          settings = (currentSettings state)
            { settingsEditor = if T.null executable then Nothing else Just (T.unpack executable) }
          updated = (applySettings settings state)
            { stMode = Browse, stInputCursor = 0, stStatus = SettingsSaved }
      in persistSettings state updated
