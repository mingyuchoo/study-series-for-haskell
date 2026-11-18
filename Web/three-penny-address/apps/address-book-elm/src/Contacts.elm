module Contacts exposing (Contact, Draft, empty, fromContact, list, remove, save)

import Http
import Json.Decode as Decode
import Json.Encode as Encode
import Url


type alias Draft =
    { name : String
    , phone : String
    , email : String
    , address : String
    }


type alias Contact =
    { id : String
    , draft : Draft
    }


empty : Draft
empty =
    Draft "" "" "" ""


fromContact : Contact -> Draft
fromContact =
    .draft


list : String -> (Result String (List Contact) -> msg) -> Cmd msg
list query toMessage =
    Http.get
        { url = "/api/contacts?q=" ++ Url.percentEncode query
        , expect = expectResponse toMessage (Decode.decodeString (Decode.list contactDecoder) >> Result.mapError (\_ -> "Invalid contact list."))
        }


save : Maybe String -> Draft -> (Result String () -> msg) -> Cmd msg
save identifier draft toMessage =
    Http.post
        { url = "/api/contacts"
        , body =
            Http.jsonBody <|
                Encode.object
                    [ ( "id", Maybe.map Encode.string identifier |> Maybe.withDefault Encode.null )
                    , ( "name", Encode.string draft.name )
                    , ( "phone", Encode.string draft.phone )
                    , ( "email", Encode.string draft.email )
                    , ( "address", Encode.string draft.address )
                    ]
        , expect = expectResponse toMessage (always (Ok ()))
        }


remove : String -> (Result String () -> msg) -> Cmd msg
remove identifier toMessage =
    Http.request
        { method = "DELETE"
        , headers = []
        , url = "/api/contacts/" ++ Url.percentEncode identifier
        , body = Http.emptyBody
        , expect = expectResponse toMessage (always (Ok ()))
        , timeout = Nothing
        , tracker = Nothing
        }


contactDecoder : Decode.Decoder Contact
contactDecoder =
    Decode.map2 Contact
        (Decode.field "id" Decode.string)
        (Decode.map4 Draft
            (Decode.field "name" Decode.string)
            (optionalField "phone")
            (optionalField "email")
            (optionalField "address")
        )


optionalField : String -> Decode.Decoder String
optionalField field =
    Decode.field field (Decode.nullable Decode.string)
        |> Decode.map (Maybe.withDefault "")


expectResponse : (Result String a -> msg) -> (String -> Result String a) -> Http.Expect msg
expectResponse toMessage decode =
    Http.expectStringResponse toMessage <|
        \response ->
            case response of
                Http.GoodStatus_ _ body ->
                    decode body

                Http.BadStatus_ metadata body ->
                    Decode.decodeString (Decode.field "message" Decode.string) body
                        |> Result.withDefault ("The server returned HTTP " ++ String.fromInt metadata.statusCode ++ ".")
                        |> Err

                Http.BadUrl_ _ ->
                    Err "Invalid request URL."

                Http.Timeout_ ->
                    Err "The request timed out."

                Http.NetworkError_ ->
                    Err "Could not reach the address book server."
