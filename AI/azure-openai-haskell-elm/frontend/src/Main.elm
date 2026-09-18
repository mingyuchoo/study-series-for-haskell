module Main exposing (main)

{-| Clean Architecture 기반 메인 애플리케이션
-}

import Application.ChatState as ChatState exposing (ChatState)
import Application.ChatUseCase as ChatUseCase
import Browser
import Domain.ChatService as ChatService
import Html exposing (Html)
import Infrastructure.Http.ChatApi as ChatApi
import Presentation.View as View



-- MAIN


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }



-- MODEL


type alias Flags =
    { apiUrl : String
    , theme : Maybe String
    }


type alias Model =
    { chatState : ChatState
    , apiUrl : String
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        initialTheme =
            flags.theme
                |> Maybe.map ChatState.stringToTheme
                |> Maybe.withDefault ChatState.Dark
    in
    ( { chatState = ChatState.initWithTheme initialTheme
      , apiUrl = flags.apiUrl
      }
    , Cmd.none
    )



-- UPDATE


type Msg
    = UpdateInput String
    | SendMessage
    | GotResponse (Result String String)
    | ClearChat
    | KeyDown Int
    | ToggleTheme


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UpdateInput newInput ->
            ( { model | chatState = ChatUseCase.updateInput newInput model.chatState }
            , Cmd.none
            )

        SendMessage ->
            let
                ( newState, maybeMessage ) =
                    ChatUseCase.sendUserMessage (ChatState.getInput model.chatState) model.chatState
            in
            case maybeMessage of
                Just _ ->
                    ( { model | chatState = newState }
                    , ChatService.sendMessage
                        (ChatApi.chatService GotResponse)
                        model.apiUrl
                        (ChatState.getMessages newState)
                    )

                Nothing ->
                    ( model, Cmd.none )

        GotResponse result ->
            ( { model | chatState = ChatUseCase.handleResponse result model.chatState }
            , Cmd.none
            )

        ClearChat ->
            ( { model | chatState = ChatUseCase.clearChat model.chatState }
            , Cmd.none
            )

        KeyDown key ->
            if key == 13 then
                update SendMessage model

            else
                ( model, Cmd.none )

        ToggleTheme ->
            ( { model | chatState = ChatUseCase.toggleTheme model.chatState }
            , Cmd.none
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Model -> Html Msg
view model =
    View.view
        { onUpdateInput = UpdateInput
        , onSendMessage = SendMessage
        , onClearChat = ClearChat
        , onKeyDown = KeyDown
        , onSelectPrompt = UpdateInput
        , onToggleTheme = ToggleTheme
        }
        model.chatState
