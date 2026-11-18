module TodoApi exposing (create, delete, fetch, update)

import Http
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Todo exposing (Todo)


endpoint : String
endpoint =
    "/api/todos"


itemUrl : Int -> String
itemUrl id =
    endpoint ++ "/" ++ String.fromInt id


fetch : (Result String (List Todo) -> msg) -> Cmd msg
fetch =
    request "GET" endpoint Http.emptyBody (Decode.map Ok (Decode.list todoDecoder))


create : String -> (Result String (List Todo) -> msg) -> Cmd msg
create title =
    request "POST"
        endpoint
        (Http.jsonBody (Encode.object [ ( "newTodoTitle", Encode.string title ) ]))
        validationDecoder


update : Todo -> (Result String (List Todo) -> msg) -> Cmd msg
update todo =
    request "PUT"
        (itemUrl todo.id)
        (Http.jsonBody
            (Encode.object
                [ ( "todoId", Encode.int todo.id )
                , ( "todoTitle", Encode.string todo.title )
                , ( "createdAt", Encode.string todo.createdAt )
                , ( "priority", Encode.string (Todo.priorityName todo.priority) )
                , ( "status", Encode.string (Todo.statusName todo.status ++ "Status") )
                ]
            )
        )
        validationDecoder


delete : Int -> (Result String (List Todo) -> msg) -> Cmd msg
delete id =
    request "DELETE" (itemUrl id) Http.emptyBody (Decode.map Ok (Decode.list todoDecoder))


request : String -> String -> Http.Body -> Decoder (Result String a) -> (Result String a -> msg) -> Cmd msg
request method url body decoder receive =
    Http.request
        { method = method
        , url = url
        , headers = []
        , body = body
        , expect = Http.expectJson (Result.mapError describeError >> Result.andThen identity >> receive) decoder
        , timeout = Just 15000
        , tracker = Nothing
        }


describeError : Http.Error -> String
describeError error =
    case error of
        Http.BadUrl _ ->
            "The task service address is invalid."

        Http.Timeout ->
            "The task service timed out."

        Http.NetworkError ->
            "Could not reach the task service."

        Http.BadStatus code ->
            "The task service returned HTTP " ++ String.fromInt code ++ "."

        Http.BadBody _ ->
            "The task service returned an unreadable response."


validationDecoder : Decoder (Result String (List Todo))
validationDecoder =
    Decode.oneOf
        [ Decode.field "Right" (Decode.map Ok (Decode.list todoDecoder))
        , Decode.field "Left" (Decode.field "errorMessage" (Decode.map Err Decode.string))
        ]


todoDecoder : Decoder Todo
todoDecoder =
    Decode.map5 Todo
        (Decode.field "todoId" Decode.int)
        (Decode.field "todoTitle" Decode.string)
        (Decode.field "createdAt" Decode.string)
        (Decode.field "priority" (enumDecoder Todo.priorities Todo.priorityName))
        (Decode.field "status" (enumDecoder Todo.statuses Todo.statusName))


enumDecoder : List a -> (a -> String) -> Decoder a
enumDecoder values name =
    Decode.string
        |> Decode.andThen
            (\label ->
                case List.filter (\value -> name value == label) values of
                    value :: _ ->
                        Decode.succeed value

                    [] ->
                        Decode.fail ("Unexpected value: " ++ label)
            )
