module Presentation.Components.InputArea exposing (view)

{-| Saniti 디자인 시스템 기반 입력 영역 컴포넌트
-}

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (custom, onClick, onInput)
import Json.Decode as Decode


view : String -> Bool -> (String -> msg) -> (Int -> msg) -> msg -> Html msg
view input loading onInputMsg onKeyDownMsg onSendMsg =
    div [ class "input-container" ]
        [ div [ class "input-meta-bar" ]
            [ span [ class "input-hint mono-micro" ]
                [ text "INPUT CONSOLE // PRESS [ENTER] TO DISPATCH · [SHIFT+ENTER] FOR NEWLINE" ]
            , span [ class "input-status mono-micro" ]
                [ text "AZURE OPENAI · BUFFER: ACTIVE" ]
            ]
        , div [ class "input-field-row" ]
            [ textarea
                [ value input
                , onInput onInputMsg
                , onKeyDownCustom onKeyDownMsg
                , placeholder "Type an inquiry or prompt... (Press Enter to dispatch)"
                , disabled loading
                , rows 3
                , class "studio-textarea"
                ]
                []
            , button
                [ onClick onSendMsg
                , disabled (String.trim input == "" || loading)
                , class "button-brand send-button"
                ]
                [ if loading then
                    span [ class "btn-content" ]
                        [ span [ class "btn-spinner" ] []
                        , text "Reasoning..."
                        ]

                  else
                    span [ class "btn-content" ]
                        [ text "Dispatch"
                        , span [ class "btn-arrow" ] [ text " →" ]
                        ]
                ]
            ]
        ]


onKeyDownCustom : (Int -> msg) -> Attribute msg
onKeyDownCustom tagger =
    custom "keydown"
        (Decode.map2
            (\code shift ->
                if code == 13 && not shift then
                    { message = tagger 13
                    , stopPropagation = False
                    , preventDefault = True
                    }

                else
                    { message = tagger 0
                    , stopPropagation = False
                    , preventDefault = False
                    }
            )
            (Decode.field "keyCode" Decode.int)
            (Decode.field "shiftKey" Decode.bool)
        )
