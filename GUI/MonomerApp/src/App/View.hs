module App.View
  ( buildUI
  )
where

import App.Event (AppEvent (AppIncrease))
import App.Model (AppModel, clickCount)
import Control.Lens ((^.))
import Monomer
  ( WidgetEnv,
    WidgetNode,
    button,
    hstack,
    label,
    padding,
    spacer,
    styleBasic,
    vstack,
  )
import TextShow (showt)

buildUI ::
  WidgetEnv AppModel AppEvent ->
  AppModel ->
  WidgetNode AppModel AppEvent
buildUI _ model =
  vstack
    [ label "Hello world",
      spacer,
      hstack
        [ label $ "Click count: " <> showt (model ^. clickCount),
          spacer,
          button "Increase count" AppIncrease
        ]
    ]
    `styleBasic` [padding 10]
