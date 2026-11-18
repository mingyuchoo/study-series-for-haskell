module Main exposing (main)

import Application.Management as Management exposing (Effect, Model, Msg)
import Browser
import Infrastructure.Effects as Effects
import Presentation.Directory as Directory


main : Program () Model Msg
main =
    Browser.element
        { init = \_ -> execute Management.initial
        , update = \message model -> execute (Management.update message model)
        , view = Directory.view
        , subscriptions = \_ -> Sub.none
        }


execute : ( Model, List Effect ) -> ( Model, Cmd Msg )
execute ( model, effects ) =
    ( model, Cmd.batch (List.map Effects.perform effects) )
