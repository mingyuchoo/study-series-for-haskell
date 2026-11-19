module Lib (app) where

import Brick (App (..), showCursorNamed)
import Todo.Application.Repository (Repository)
import Todo.Application.Workflow qualified as Workflow
import UI.Attributes (theMap)
import UI.Draw (drawUI)
import UI.Events (dispatch, handleEvent)
import UI.Types

app :: Repository IO -> App AppState e Name
app repository =
  App
    { appDraw = drawUI
    , appChooseCursor = \state locations -> case appMode state of
        ViewMode -> Nothing
        _ -> showCursorNamed (fieldName $ activeField state) locations
    , appHandleEvent = handleEvent repository
    , appStartEvent = dispatch repository Workflow.Start
    , appAttrMap = const theMap
    }

fieldName :: FocusedField -> Name
fieldName FocusAction = ActionField
fieldName FocusSubject = SubjectField
fieldName FocusIndirectObject = IndirectObjectField
fieldName FocusDirectObject = DirectObjectField
