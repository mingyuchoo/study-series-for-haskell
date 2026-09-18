module Application.ChatUseCase exposing
    ( clearChat
    , handleResponse
    , sendUserMessage
    , setTheme
    , toggleTheme
    , updateInput
    )

{-| 채팅 유스케이스 - 비즈니스 로직
-}

import Application.ChatState as ChatState exposing (ChatState, Theme)
import Domain.Message as Message exposing (Message)


sendUserMessage : String -> ChatState -> ( ChatState, Maybe Message )
sendUserMessage input state =
    let
        trimmedInput =
            String.trim input
    in
    if trimmedInput == "" || ChatState.isLoading state then
        ( state, Nothing )

    else
        let
            userMessage =
                Message.create Message.User trimmedInput

            newState =
                state
                    |> ChatState.addMessage userMessage
                    |> ChatState.updateInput ""
                    |> ChatState.setLoading True
                    |> ChatState.clearError
        in
        ( newState, Just userMessage )


handleResponse : Result String String -> ChatState -> ChatState
handleResponse result state =
    case result of
        Ok response ->
            let
                assistantMessage =
                    Message.create Message.Assistant response
            in
            state
                |> ChatState.addMessage assistantMessage
                |> ChatState.setLoading False

        Err error ->
            state
                |> ChatState.setError error


clearChat : ChatState -> ChatState
clearChat =
    ChatState.clearMessages


updateInput : String -> ChatState -> ChatState
updateInput =
    ChatState.updateInput


toggleTheme : ChatState -> ChatState
toggleTheme =
    ChatState.toggleTheme


setTheme : Theme -> ChatState -> ChatState
setTheme =
    ChatState.setTheme
