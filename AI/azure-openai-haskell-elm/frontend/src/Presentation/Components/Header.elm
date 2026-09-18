module Presentation.Components.Header exposing (view)

{-| Saniti 디자인 시스템 기반 헤더 컴포넌트
-}

import Application.ChatState exposing (Theme(..))
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)


view : Theme -> Bool -> msg -> msg -> Html msg
view theme hasMessages clearMsg toggleThemeMsg =
    header [ class "nav-bar nav-bar-dark" ]
        [ div [ class "nav-left" ]
            [ span [ class "brand-dot" ] []
            , span [ class "brand-wordmark" ] [ text "Saniti" ]
            , span [ class "brand-divider" ] [ text "/" ]
            , span [ class "brand-sub" ] [ text "Azure OpenAI Studio" ]
            , span [ class "badge-version mono-caps" ] [ text "STUDIO // v1.0" ]
            ]
        , div [ class "nav-center" ]
            [ div [ class "status-pill" ]
                [ span [ class "status-dot" ] []
                , span [ class "status-label mono-caps" ] [ text "AZURE OPENAI · READY" ]
                ]
            ]
        , div [ class "nav-right" ]
            [ button
                [ class "button-secondary button-theme-toggle mono-caps"
                , onClick toggleThemeMsg
                , title
                    (case theme of
                        Dark ->
                            "Switch to Light Theme"

                        Light ->
                            "Switch to Dark Theme"
                    )
                ]
                [ span [ class "theme-icon" ]
                    [ text
                        (case theme of
                            Dark ->
                                "☼"

                            Light ->
                                "☽"
                        )
                    ]
                , span [ class "theme-label" ]
                    [ text
                        (case theme of
                            Dark ->
                                "LIGHT"

                            Light ->
                                "DARK"
                        )
                    ]
                ]
            , if hasMessages then
                button [ class "button-secondary button-secondary-dark", onClick clearMsg ]
                    [ text "New Session" ]

              else
                button [ class "button-secondary button-secondary-dark is-disabled", disabled True ]
                    [ text "New Session" ]
            ]
        ]
