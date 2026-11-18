module Presentation.Editor exposing (view)

import Application.Management exposing (Model, Msg(..), Pending(..), isBusy)
import Html exposing (Html, button, div, form, h2, input, label, p, section, span, text)
import Html.Attributes exposing (attribute, class, disabled, for, id, name, placeholder, type_, value)
import Html.Events exposing (onClick, onInput, onSubmit)


view : Model -> Html Msg
view model =
    section [ class "editor-card", id "add-user", attribute "aria-labelledby" "editor-title" ]
        [ div [ class "section-eyebrow" ] [ text "MAKE ROOM FOR SOMEONE" ]
        , h2 [ id "editor-title" ]
            [ text
                (if model.selected == Nothing then
                    "One more good person."

                 else
                    "A fresh introduction."
                )
            ]
        , p [ class "editor-description" ]
            [ text
                (case model.selected of
                    Just user ->
                        "Update the name for user #" ++ String.fromInt user.id ++ "."

                    Nothing ->
                        "Add someone to your workspace. All it takes is a name."
                )
            ]
        , form [ onSubmit Submit, attribute "novalidate" "" ]
            [ label [ for "user-name" ] [ text "Full name" ]
            , input
                [ id "user-name"
                , name "name"
                , type_ "text"
                , attribute "autocomplete" "name"
                , placeholder "e.g. Ada Lovelace"
                , value model.name
                , disabled (isBusy model)
                , onInput NameChanged
                , attribute "aria-invalid"
                    (if model.nameError == Nothing then
                        "false"

                     else
                        "true"
                    )
                , attribute "aria-describedby" "name-help"
                ]
                []
            , p
                [ id "name-help"
                , class
                    (if model.nameError == Nothing then
                        "field-help"

                     else
                        "field-help field-error"
                    )
                , attribute "aria-live" "polite"
                ]
                [ text (Maybe.withDefault "Use the name people know them by." model.nameError) ]
            , button [ type_ "submit", class "button button-primary button-wide", disabled (isBusy model || model.deletion /= Nothing) ]
                [ text
                    (case model.pending of
                        Just Creating ->
                            "Adding person…"

                        Just (Updating _) ->
                            "Saving changes…"

                        _ ->
                            if model.selected == Nothing then
                                "Add person"

                            else
                                "Save changes"
                    )
                , span [ attribute "aria-hidden" "true" ] [ text "↗" ]
                ]
            , if model.selected /= Nothing then
                button [ type_ "button", class "button button-secondary button-wide cancel-edit", disabled (isBusy model), onClick CancelEdit ] [ text "Cancel editing" ]

              else
                text ""
            ]
        , div [ class "editor-note" ]
            [ span [ class "note-mark", attribute "aria-hidden" "true" ] [ text "✳" ]
            , p [] [ text "A shared space begins with the people in it." ]
            ]
        ]
