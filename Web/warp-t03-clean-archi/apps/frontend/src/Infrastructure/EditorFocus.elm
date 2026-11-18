module Infrastructure.EditorFocus exposing (focus)

import Application.Management exposing (Msg(..))
import Browser.Dom
import Task


focus : Cmd Msg
focus =
    Browser.Dom.focus "user-name"
        |> Task.attempt
            (Result.mapError (always "The name field is unavailable. Refresh the page and try again.") >> EditorFocused)
