module Hfm.Domain.Theme (Theme (..), themes, themeName) where

import Data.Text (Text)

-- Theme identity is independent of terminal colors and rendering libraries.
data Theme = Light | Dark | Monokai | SolarizedLight | SolarizedDark | TomorrowNightBlue | GruvboxDark | GruvboxLight
  deriving (Eq, Show, Enum, Bounded)

themes :: [Theme]
themes = [minBound .. maxBound]

themeName :: Theme -> Text
themeName Light = "Light"
themeName Dark = "Dark"
themeName Monokai = "Monokai"
themeName SolarizedLight = "Solarized Light"
themeName SolarizedDark = "Solarized Dark"
themeName TomorrowNightBlue = "Tomorrow Night Blue"
themeName GruvboxDark = "Gruvbox Dark"
themeName GruvboxLight = "Gruvbox Light"
