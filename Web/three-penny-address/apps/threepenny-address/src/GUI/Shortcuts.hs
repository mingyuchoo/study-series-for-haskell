module GUI.Shortcuts (registerShortcuts) where

import Control.Monad (void)
import Graphics.UI.Threepenny qualified as UI
import Graphics.UI.Threepenny.Core

registerShortcuts :: Element -> UI () -> UI () -> UI () -> UI () -> UI ()
registerShortcuts container triggerAddContact triggerDeleteContact triggerCancelOperation triggerFocusSearch = do
  shortcutNewBtn <-
    UI.button
      # set (UI.attr "id") "shortcut-new"
      # set UI.style [("display", "none")]
  shortcutDeleteBtn <-
    UI.button
      # set (UI.attr "id") "shortcut-delete"
      # set UI.style [("display", "none")]
  shortcutCancelBtn <-
    UI.button
      # set (UI.attr "id") "shortcut-cancel"
      # set UI.style [("display", "none")]
  shortcutSearchBtn <-
    UI.button
      # set (UI.attr "id") "shortcut-search"
      # set UI.style [("display", "none")]

  on UI.click shortcutNewBtn $ \_ -> triggerAddContact
  on UI.click shortcutDeleteBtn $ \_ -> triggerDeleteContact
  on UI.click shortcutCancelBtn $ \_ -> triggerCancelOperation
  on UI.click shortcutSearchBtn $ \_ -> triggerFocusSearch

  runFunction $
    ffi
      "document.addEventListener('keydown', function(e) { \
      \  var keyCode = e.keyCode || e.which; \
      \  var ctrlKey = e.ctrlKey || e.metaKey; \
      \  var activeTag = document.activeElement ? document.activeElement.tagName.toLowerCase() : ''; \
      \  var isInputFocused = (activeTag === 'input' || activeTag === 'textarea'); \
      \  if (ctrlKey && keyCode === 78) { \
      \    e.preventDefault(); \
      \    var btn = document.getElementById('shortcut-new'); \
      \    if (btn) btn.click(); \
      \  } else if (ctrlKey && keyCode === 70) { \
      \    e.preventDefault(); \
      \    var btn = document.getElementById('shortcut-search'); \
      \    if (btn) btn.click(); \
      \  } else if (keyCode === 46 && !isInputFocused) { \
      \    e.preventDefault(); \
      \    var btn = document.getElementById('shortcut-delete'); \
      \    if (btn) btn.click(); \
      \  } else if (keyCode === 27) { \
      \    e.preventDefault(); \
      \    var btn = document.getElementById('shortcut-cancel'); \
      \    if (btn) btn.click(); \
      \  } \
      \});"

  void $ element container #+ map element [shortcutNewBtn, shortcutDeleteBtn, shortcutCancelBtn, shortcutSearchBtn]
