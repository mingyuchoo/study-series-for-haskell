module Presentation.Components.MessageList exposing (view)

{-| Saniti 디자인 시스템 기반 메시지 리스트 컴포넌트
-}

import Domain.Message as Message exposing (Message)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)


view : (String -> msg) -> List Message -> Bool -> Maybe String -> Html msg
view onSelectPrompt messages loading error =
    div [ class "messages-container" ]
        (if List.isEmpty messages then
            [ viewWelcome onSelectPrompt ]

         else
            List.map viewMessage messages
                ++ (if loading then
                        [ viewLoadingMessage ]

                    else
                        []
                   )
                ++ (case error of
                        Just err ->
                            [ viewError err ]

                        Nothing ->
                            []
                   )
        )


viewWelcome : (String -> msg) -> Html msg
viewWelcome onSelectPrompt =
    div [ class "welcome-hero" ]
        [ div [ class "hero-eyebrow mono-eyebrow" ]
            [ text "// CONVERSATIONAL REASONING ENGINE" ]
        , h1 [ class "hero-title display-md" ]
            [ text "Structure powers intelligence" ]
        , p [ class "hero-subtitle subtitle" ]
            [ text "A dark-first engineering console integrating Haskell Clean Architecture with Azure OpenAI conversational reasoning." ]
        , div [ class "prompt-cards-grid" ]
            [ viewPromptCard onSelectPrompt
                "SYSTEM ARCHITECTURE"
                "Clean Architecture Invariants"
                "Explain how Ports & Adapters decouple Domain entities from Servant API and Elm UI."
                "Clean Architecture 원칙에서 Domain 계층과 Infrastructure 계층의 경계 및 의존성 역전 원칙(DIP)에 대해 설명해줘."
            , viewPromptCard onSelectPrompt
                "HASKELL SERVICE"
                "Servant & Azure Client"
                "Trace request flow from Servant API handlers to Azure OpenAI REST endpoints."
                "Haskell Servant API 핸들러에서 Azure OpenAI REST API를 호출하고 응답을 파싱하는 흐름을 설명해줘."
            , viewPromptCard onSelectPrompt
                "EDITORIAL SPEC"
                "Saniti Design Tokens"
                "Review the 112px display scale, IBM Plex Mono eyebrows, and coral-red accent."
                "Saniti 디자인 시스템의 다크 퍼스트 에디토리얼 레이아웃과 타이포그래피 계층 구조에 대해 요약해줘."
            ]
        ]


viewPromptCard : (String -> msg) -> String -> String -> String -> String -> Html msg
viewPromptCard onSelectPrompt eyebrow title desc prompt =
    button
        [ class "feature-card-dark prompt-card"
        , onClick (onSelectPrompt prompt)
        ]
        [ div [ class "prompt-card-eyebrow mono-caps" ] [ text eyebrow ]
        , div [ class "prompt-card-title heading-sm" ] [ text title ]
        , div [ class "prompt-card-desc body-sm" ] [ text desc ]
        , div [ class "prompt-card-action mono-micro" ] [ text "LOAD PROMPT →" ]
        ]


viewMessage : Message -> Html msg
viewMessage message =
    case message.role of
        Message.User ->
            div [ class "message-row user-row" ]
                [ div [ class "message-wrapper user-wrapper" ]
                    [ div [ class "message-meta-header" ]
                        [ span [ class "message-role-tag mono-caps" ] [ text "OPERATOR // YOU" ]
                        ]
                    , div [ class "message-card user-card" ]
                        [ div [ class "message-content" ] [ text message.content ]
                        ]
                    ]
                ]

        Message.Assistant ->
            div [ class "message-row assistant-row" ]
                [ div [ class "message-wrapper assistant-wrapper" ]
                    [ div [ class "message-meta-header" ]
                        [ span [ class "assistant-brand-dot" ] []
                        , span [ class "message-role-tag mono-caps" ] [ text "ASSISTANT // AZURE OPENAI" ]
                        ]
                    , div [ class "message-card assistant-card" ]
                        [ div [ class "message-content" ] [ text message.content ]
                        ]
                    ]
                ]


viewLoadingMessage : Html msg
viewLoadingMessage =
    div [ class "message-row assistant-row" ]
        [ div [ class "message-wrapper assistant-wrapper" ]
            [ div [ class "message-meta-header" ]
                [ span [ class "assistant-brand-dot pulse" ] []
                , span [ class "message-role-tag mono-caps" ] [ text "ASSISTANT // REASONING..." ]
                ]
            , div [ class "message-card assistant-card loading-card" ]
                [ div [ class "reasoning-state" ]
                    [ span [ class "reasoning-dot" ] []
                    , span [ class "reasoning-text mono-eyebrow" ]
                        [ text "Synthesizing response from Azure OpenAI deployment..." ]
                    ]
                ]
            ]
        ]


viewError : String -> Html msg
viewError err =
    div [ class "message-row error-row" ]
        [ div [ class "alert-banner" ]
            [ div [ class "alert-header mono-caps" ]
                [ text "SYSTEM EXCEPTION // API ERROR" ]
            , div [ class "alert-body" ]
                [ text err ]
            ]
        ]
