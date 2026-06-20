module App.Config
  ( appConfig
  ) where

import App.Event (AppEvent (AppInit))
import App.Model (AppModel)
import Monomer
  ( AppConfig
  , appFontDef
  , appInitEvent
  , appTheme
  , appWindowIcon
  , appWindowTitle
  , darkTheme
  )

appConfig :: [AppConfig AppModel AppEvent]
appConfig =
  [ appWindowTitle "Hello world"
  , appWindowIcon "./assets/images/icon.png"
  , appTheme darkTheme
  , appFontDef "Regular" "./assets/fonts/Roboto-Regular.ttf"
  , appInitEvent AppInit
  ]
