module Infrastructure.UserApi exposing (load, remove, save, userDecoder)

import Application.Management exposing (Msg(..))
import Domain.User exposing (User)
import Http
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode


userDecoder : Decoder User
userDecoder =
    Decode.map2 User (Decode.field "id" Decode.int) (Decode.field "name" Decode.string)


load : Cmd Msg
load =
    Http.request
        { method = "GET"
        , headers = []
        , url = "/api/users"
        , body = Http.emptyBody
        , expect = Http.expectJson (Result.mapError errorMessage >> UsersLoaded) (Decode.list userDecoder)
        , timeout = Just 15000
        , tracker = Nothing
        }


save : Maybe Int -> String -> Cmd Msg
save identifier name =
    Http.request
        { method = Maybe.map (always "PUT") identifier |> Maybe.withDefault "POST"
        , headers = []
        , url = userUrl identifier
        , body = Http.jsonBody (Encode.object [ ( "name", Encode.string name ) ])
        , expect = Http.expectJson (Result.mapError errorMessage >> UserSaved) userDecoder
        , timeout = Just 15000
        , tracker = Nothing
        }


remove : Int -> Cmd Msg
remove identifier =
    Http.request
        { method = "DELETE"
        , headers = []
        , url = userUrl (Just identifier)
        , body = Http.emptyBody
        , expect = Http.expectWhatever (Result.mapError errorMessage >> UserDeleted)
        , timeout = Just 15000
        , tracker = Nothing
        }


userUrl : Maybe Int -> String
userUrl identifier =
    "/api/users" ++ (Maybe.map (String.fromInt >> (++) "/") identifier |> Maybe.withDefault "")


errorMessage : Http.Error -> String
errorMessage problem =
    case problem of
        Http.NetworkError ->
            "We couldn't reach the server. Check your connection and try again."

        Http.Timeout ->
            "The request timed out. Please try again."

        Http.BadStatus 404 ->
            "This user no longer exists. Refresh the directory to get the latest users."

        Http.BadStatus _ ->
            "The server couldn't complete your request. Please try again."

        Http.BadBody _ ->
            "The server returned unexpected data. Please refresh and try again."

        Http.BadUrl _ ->
            "The user service address is invalid."
