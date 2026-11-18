module Infrastructure.Effects exposing (perform)

import Application.Management exposing (Effect(..), Msg)
import Infrastructure.EditorFocus as EditorFocus
import Infrastructure.UserApi as UserApi


perform : Effect -> Cmd Msg
perform effect =
    case effect of
        LoadUsers ->
            UserApi.load

        SaveUser identifier name ->
            UserApi.save identifier name

        RemoveUser identifier ->
            UserApi.remove identifier

        FocusEditor ->
            EditorFocus.focus
