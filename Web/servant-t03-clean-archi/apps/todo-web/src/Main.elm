module Main exposing (main)

import Browser
import Workspace
import WorkspaceView


main : Program () Workspace.Model Workspace.Msg
main =
    Browser.element
        { init = Workspace.init
        , update = Workspace.update
        , view = WorkspaceView.view
        , subscriptions = always Sub.none
        }
