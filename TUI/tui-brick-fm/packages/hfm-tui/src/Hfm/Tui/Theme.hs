module Hfm.Tui.Theme (themeAttributes, effectiveTheme) where

import Brick (AttrMap, attrMap, attrName, on)
import Brick.Widgets.List (listSelectedAttr, listSelectedFocusedAttr)
import qualified Graphics.Vty as V
import Hfm.Application.State (AppState (..))
import Hfm.Domain.Selection (selectedElement)
import Hfm.Domain.Theme

-- RGB adaptation of VS Code's built-in editor/list/status colors.
-- Source: https://github.com/microsoft/vscode/tree/main/extensions
-- Light/Dark use the Visual Studio defaults. Alpha colors are replaced with
-- opaque selection colors because terminal attributes do not support alpha.
data Palette = Palette
  { foreground :: Int
  , background :: Int
  , surface :: Int
  , barForeground :: Int
  , barBackground :: Int
  , accent :: Int
  , selectionForeground :: Int
  , selectionBackground :: Int
  , inactiveSelection :: Int
  , keyword :: Int
  , stringColor :: Int
  , number :: Int
  , comment :: Int
  }

palette :: Theme -> Palette
palette Light = Palette
  0x000000 0xFFFFFF 0xF3F3F3 0xFFFFFF 0x007ACC 0x0451A5
  0xFFFFFF 0x007ACC 0xE5EBF1 0x0000FF 0xA31515 0x098658 0x008000
palette Dark = Palette
  0xD4D4D4 0x1E1E1E 0x252526 0xFFFFFF 0x007ACC 0x569CD6
  0xFFFFFF 0x094771 0x3A3D41 0x569CD6 0xCE9178 0xB5CEA8 0x6A9955
palette Monokai = Palette
  0xF8F8F2 0x272822 0x1E1F1C 0xF8F8F2 0x414339 0xA6E22E
  0xF8F8F2 0x75715E 0x414339 0xF92672 0xE6DB74 0xAE81FF 0x88846F
palette SolarizedLight = Palette
  0x657B83 0xFDF6E3 0xEEE8D5 0x586E75 0xEEE8D5 0x268BD2
  0x073642 0xDFCA88 0xD1CBB8 0x859900 0x2AA198 0xD33682 0x93A1A1
palette SolarizedDark = Palette
  0x839496 0x002B36 0x073642 0x93A1A1 0x00212B 0x2AA198
  0xEEE8D5 0x005A6F 0x004454 0x859900 0x2AA198 0xD33682 0x586E75
palette TomorrowNightBlue = Palette
  0xFFFFFF 0x002451 0x001C40 0xFFFFFF 0x001126 0xBBDAFF
  0xFFFFFF 0x003F8E 0x00346E 0xFF9DA4 0xD1F1A9 0xFFC58F 0x7285B7

rgb :: Int -> V.Color
rgb value = V.rgbColor (value `div` 65536) ((value `div` 256) `mod` 256) (value `mod` 256)

-- Selection is a preview until Enter commits it in the application layer.
effectiveTheme :: AppState -> Theme
effectiveTheme st = maybe (stTheme st) snd (stThemePicker st >>= selectedElement)

themeAttributes :: Theme -> AttrMap
themeAttributes theme =
  let p = palette theme
      base = rgb (foreground p) `on` rgb (background p)
      bars = rgb (barForeground p) `on` rgb (barBackground p)
      selected = rgb (selectionForeground p) `on` rgb (selectionBackground p)
      inactive = rgb (foreground p) `on` rgb (inactiveSelection p)
      syntax color = rgb color `on` rgb (background p)
  in attrMap base
    [ (listSelectedAttr, inactive)
    , (listSelectedFocusedAttr, selected)
    , (attrName "default", base)
    , (attrName "header", bars)
    , (attrName "keys", bars)
    , (attrName "status", bars)
    , (attrName "input", rgb (foreground p) `on` rgb (surface p))
    , (attrName "active", rgb (accent p) `on` rgb (background p))
    , (attrName "inactive", base)
    , (attrName "selected", selected)
    , (attrName "selectedInactive", inactive)
    , (attrName "syntax.keyword", syntax (keyword p))
    , (attrName "syntax.type", syntax (accent p))
    , (attrName "syntax.number", syntax (number p))
    , (attrName "syntax.string", syntax (stringColor p))
    , (attrName "syntax.comment", syntax (comment p))
    , (attrName "syntax.function", syntax (accent p))
    , (attrName "syntax.lineNumber", syntax (comment p))
    ]
