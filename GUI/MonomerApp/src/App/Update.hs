module App.Update
  ( handleEvent,
    updateModel,
  )
where

import App.Event (AppEvent (..))
import App.Model (AppModel, increaseClickCount)
import Monomer (AppEventResponse, EventResponse (Model), WidgetEnv, WidgetNode)

updateModel :: AppEvent -> AppModel -> AppModel
updateModel AppInit model = model
updateModel AppIncrease model = increaseClickCount model

handleEvent ::
  WidgetEnv AppModel AppEvent ->
  WidgetNode AppModel AppEvent ->
  AppModel ->
  AppEvent ->
  [AppEventResponse AppModel AppEvent]
handleEvent _ _ _ AppInit = []
handleEvent _ _ model event = [Model (updateModel event model)]
