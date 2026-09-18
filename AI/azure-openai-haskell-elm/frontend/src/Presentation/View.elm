module Presentation.View exposing (view)

{-| Saniti 디자인 시스템 기반 메인 뷰 조합
-}

import Application.ChatState as ChatState exposing (ChatState)
import Html exposing (..)
import Html.Attributes exposing (..)
import Presentation.Components.Header as Header
import Presentation.Components.InputArea as InputArea
import Presentation.Components.MessageList as MessageList


type alias ViewConfig msg =
    { onUpdateInput : String -> msg
    , onSendMessage : msg
    , onClearChat : msg
    , onKeyDown : Int -> msg
    , onSelectPrompt : String -> msg
    , onToggleTheme : msg
    }


view : ViewConfig msg -> ChatState -> Html msg
view config state =
    let
        theme =
            ChatState.getTheme state

        themeStr =
            ChatState.themeToString theme
    in
    div
        [ class ("app-shell theme-" ++ themeStr)
        , attribute "data-theme" themeStr
        ]
        [ Header.view
            theme
            (not (List.isEmpty (ChatState.getMessages state)))
            config.onClearChat
            config.onToggleTheme
        , main_ [ class "studio-viewport" ]
            [ div [ class "studio-window" ]
                [ div [ class "studio-chrome-bar" ]
                    [ div [ class "studio-traffic-lights" ]
                        [ span [ class "traffic-dot traffic-red" ] []
                        , span [ class "traffic-dot traffic-yellow" ] []
                        , span [ class "traffic-dot traffic-green" ] []
                        ]
                    , div [ class "studio-window-title mono-caps" ]
                        [ text "studio // azure-openai // conversational-session" ]
                    , div [ class "studio-toolbar-tabs" ]
                        [ span [ class "button-app-tab active" ] [ text "CHAT" ]
                        , span [ class "button-app-tab" ] [ text "METRICS" ]
                        ]
                    ]
                , div [ class "studio-window-content" ]
                    [ MessageList.view
                        config.onSelectPrompt
                        (ChatState.getMessages state)
                        (ChatState.isLoading state)
                        (ChatState.getError state)
                    , InputArea.view
                        (ChatState.getInput state)
                        (ChatState.isLoading state)
                        config.onUpdateInput
                        config.onKeyDown
                        config.onSendMessage
                    ]
                , div [ class "studio-status-strip" ]
                    [ div [ class "status-item mono-micro" ]
                        [ span [ class "status-dot-mini" ] []
                        , text "AZURE OPENAI SERVICE // CONNECTED"
                        ]
                    , div [ class "status-item mono-micro" ]
                        [ text "LATENCY: NOMINAL // PROTOCOL: HTTP/1.1 REST" ]
                    , div [ class "status-item mono-micro" ]
                        [ text "SANITI DESIGN SYSTEM v1.0" ]
                    ]
                ]
            ]
        ]
