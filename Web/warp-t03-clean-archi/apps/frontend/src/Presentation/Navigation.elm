module Presentation.Navigation exposing (view)

import Application.Management exposing (Model, Msg(..))
import Html exposing (Html, a, button, div, header, nav, span, text)
import Html.Attributes exposing (attribute, class, href, id, type_)
import Html.Events exposing (onClick)


view : Model -> Html Msg
view model =
    header [ class "top-bar" ]
        [ div [ class "page-container nav-content" ]
            [ a [ href "#", class "wordmark", attribute "aria-label" "Folio home", onClick CloseMenu ]
                [ span [ class "brand-mark", attribute "aria-hidden" "true" ] [ text "✳" ]
                , text "folio"
                , span [ class "workspace-label" ] [ text " / workspace" ]
                ]
            , button
                [ type_ "button"
                , class "menu-toggle button button-secondary"
                , onClick ToggleMenu
                , attribute "aria-label"
                    (if model.menuOpen then
                        "Close navigation"

                     else
                        "Open navigation"
                    )
                , attribute "aria-expanded"
                    (if model.menuOpen then
                        "true"

                     else
                        "false"
                    )
                , attribute "aria-controls" "main-navigation"
                ]
                [ span [ attribute "aria-hidden" "true" ]
                    [ text
                        (if model.menuOpen then
                            "×"

                         else
                            "☰"
                        )
                    ]
                ]
            , nav
                [ id "main-navigation"
                , class
                    (if model.menuOpen then
                        "main-nav menu-open"

                     else
                        "main-nav"
                    )
                , attribute "aria-label" "Main navigation"
                ]
                [ a [ href "#directory", class "nav-link", attribute "aria-current" "page", onClick CloseMenu ] [ text "People" ]
                , a [ href "#add-user", class "button button-secondary nav-add", onClick StartCreate ] [ text "Add a person", span [ attribute "aria-hidden" "true" ] [ text "+" ] ]
                ]
            ]
        ]
