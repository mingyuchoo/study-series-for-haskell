module Application.ChatState exposing
    ( ChatState
    , Theme(..)
    , addMessage
    , clearError
    , clearMessages
    , getError
    , getInput
    , getMessages
    , getTheme
    , init
    , initWithTheme
    , isLoading
    , setError
    , setLoading
    , setTheme
    , stringToTheme
    , themeToString
    , toggleTheme
    , updateInput
    )

{-| 채팅 상태 관리
-}

import Domain.Message exposing (Message)


type Theme
    = Dark
    | Light


type alias ChatState =
    { messages : List Message
    , input : String
    , isLoading : Bool
    , error : Maybe String
    , theme : Theme
    }


init : ChatState
init =
    initWithTheme Dark


initWithTheme : Theme -> ChatState
initWithTheme defaultTheme =
    { messages = []
    , input = ""
    , isLoading = False
    , error = Nothing
    , theme = defaultTheme
    }


addMessage : Message -> ChatState -> ChatState
addMessage message state =
    { state | messages = state.messages ++ [ message ] }


clearMessages : ChatState -> ChatState
clearMessages state =
    { state | messages = [], error = Nothing }


setLoading : Bool -> ChatState -> ChatState
setLoading loading state =
    { state | isLoading = loading }


setError : String -> ChatState -> ChatState
setError err state =
    { state | error = Just err, isLoading = False }


clearError : ChatState -> ChatState
clearError state =
    { state | error = Nothing }


updateInput : String -> ChatState -> ChatState
updateInput newInput state =
    { state | input = newInput }


getMessages : ChatState -> List Message
getMessages state =
    state.messages


getInput : ChatState -> String
getInput state =
    state.input


isLoading : ChatState -> Bool
isLoading state =
    state.isLoading


getError : ChatState -> Maybe String
getError state =
    state.error


getTheme : ChatState -> Theme
getTheme state =
    state.theme


setTheme : Theme -> ChatState -> ChatState
setTheme newTheme state =
    { state | theme = newTheme }


toggleTheme : ChatState -> ChatState
toggleTheme state =
    let
        nextTheme =
            case state.theme of
                Dark ->
                    Light

                Light ->
                    Dark
    in
    { state | theme = nextTheme }


themeToString : Theme -> String
themeToString theme =
    case theme of
        Dark ->
            "dark"

        Light ->
            "light"


stringToTheme : String -> Theme
stringToTheme str =
    case String.toLower (String.trim str) of
        "light" ->
            Light

        _ ->
            Dark
