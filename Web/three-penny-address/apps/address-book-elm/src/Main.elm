port module Main exposing (main)

import Browser
import Browser.Dom
import Contacts exposing (Contact, Draft)
import Html exposing (Html, button, div, form, h1, h3, input, label, main_, p, table, tbody, td, text, textarea, th, thead, tr)
import Html.Attributes exposing (attribute, checked, class, disabled, for, id, name, placeholder, scope, type_, value)
import Html.Events exposing (onClick, onInput, onSubmit, stopPropagationOn)
import Json.Decode
import Task


port shortcuts : (String -> msg) -> Sub msg


type Panel
    = Closed
    | Editing (Maybe String) Draft
    | Confirming String


type alias Model =
    { contacts : List Contact
    , query : String
    , requestId : Int
    , loading : Bool
    , selected : Maybe String
    , panel : Panel
    , saving : Bool
    , listError : String
    , mutationError : String
    }


type Msg
    = Search String
    | Listed Int (Result String (List Contact))
    | Select String
    | Add
    | Edit Contact
    | ConfirmDelete String
    | ChangeDraft Draft
    | Apply
    | Applied (Result String ())
    | Cancel
    | Shortcut String
    | SearchFocused (Result Browser.Dom.Error ())


main : Program () Model Msg
main =
    Browser.element
        { init = \() -> refresh (Model [] "" 0 False Nothing Closed False "" "")
        , view = view
        , update = update
        , subscriptions = \_ -> shortcuts Shortcut
        }


refresh : Model -> ( Model, Cmd Msg )
refresh model =
    let
        nextId =
            model.requestId + 1
    in
    ( { model | requestId = nextId, contacts = [], loading = True, listError = "" }
    , Contacts.list model.query (Listed nextId)
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    case message of
        Search query ->
            refresh { model | query = query }

        Listed requestId result ->
            if requestId /= model.requestId then
                ( model, Cmd.none )

            else
                case result of
                    Ok contacts ->
                        ( { model | contacts = contacts, loading = False }, Cmd.none )

                    Err error ->
                        ( { model | contacts = [], loading = False, listError = error }, Cmd.none )

        Applied result ->
            case result of
                Ok () ->
                    refresh { model | selected = Nothing, panel = Closed, saving = False, mutationError = "" }

                Err error ->
                    ( { model | saving = False, mutationError = error }, Cmd.none )

        Shortcut "search" ->
            ( model, Task.attempt SearchFocused (Browser.Dom.focus "contact-search") )

        Shortcut shortcut ->
            case shortcut of
                "add" ->
                    update Add model

                "delete" ->
                    selectedContact model
                        |> Maybe.map (\contact -> update (ConfirmDelete contact.id) model)
                        |> Maybe.withDefault ( model, Cmd.none )

                "cancel" ->
                    update Cancel model

                _ ->
                    ( model, Cmd.none )

        SearchFocused _ ->
            ( model, Cmd.none )

        _ ->
            if model.saving then
                ( model, Cmd.none )

            else
                updatePanel message model


updatePanel : Msg -> Model -> ( Model, Cmd Msg )
updatePanel message model =
    case message of
        Select identifier ->
            ( { model | selected = Just identifier }, Cmd.none )

        Add ->
            openPanel (Editing Nothing Contacts.empty) model

        Edit contact ->
            openPanel (Editing (Just contact.id) (Contacts.fromContact contact)) model

        ConfirmDelete identifier ->
            openPanel (Confirming identifier) model

        ChangeDraft draft ->
            case model.panel of
                Editing identifier _ ->
                    ( { model | panel = Editing identifier draft }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        Apply ->
            case model.panel of
                Editing identifier draft ->
                    ( { model | saving = True, mutationError = "" }, Contacts.save identifier draft Applied )

                Confirming identifier ->
                    ( { model | saving = True, mutationError = "" }, Contacts.remove identifier Applied )

                Closed ->
                    ( model, Cmd.none )

        Cancel ->
            openPanel Closed model

        _ ->
            ( model, Cmd.none )


openPanel : Panel -> Model -> ( Model, Cmd Msg )
openPanel panel model =
    ( { model | panel = panel, mutationError = "" }, Cmd.none )


selectedContact : Model -> Maybe Contact
selectedContact model =
    model.contacts
        |> List.filter (\contact -> Just contact.id == model.selected)
        |> List.head


view : Model -> Html Msg
view model =
    main_ [ class "container" ]
        [ h1 [] [ text "Address Book" ]
        , div [ class "search-section" ]
            [ label [ for "contact-search" ] [ text "Search contacts" ]
            , input [ id "contact-search", type_ "search", placeholder "Name, phone, or email", value model.query, onInput Search ] []
            ]
        , div [ class "action-section" ]
            [ action "btn-primary" "Add Contact" model.saving Add
            , case selectedContact model of
                Just contact ->
                    div [ class "selection-actions" ]
                        [ action "btn-secondary" "Edit Selected" model.saving (Edit contact)
                        , action "btn-danger" "Delete Selected" model.saving (ConfirmDelete contact.id)
                        ]

                Nothing ->
                    text ""
            ]
        , errorMessage model.listError
        , panelView model
        , contactsView model
        ]


contactsView : Model -> Html Msg
contactsView model =
    if model.loading then
        p [ attribute "role" "status" ] [ text "Loading contacts…" ]

    else if List.isEmpty model.contacts then
        if String.isEmpty model.listError then
            p [ class "empty-state" ] [ text "No contacts found." ]

        else
            text ""

    else
        div [ class "table-section" ]
            [ table [ class "contact-table" ]
                [ thead [] [ tr [] (List.map (\heading -> th [ scope "col" ] [ text heading ]) [ "Select", "Name", "Phone", "Email", "Address", "Actions" ]) ]
                , tbody [] (List.map (contactRow model.selected model.saving) model.contacts)
                ]
            ]


contactRow : Maybe String -> Bool -> Contact -> Html Msg
contactRow selected saving contact =
    let
        draft =
            contact.draft

        isSelected =
            selected == Just contact.id
    in
    tr [ class (if isSelected then "selected" else ""), onClick (Select contact.id) ]
        [ td [] [ input [ type_ "radio", name "contact-select", checked isSelected, disabled saving, attribute "aria-label" ("Select " ++ draft.name) ] [] ]
        , td [] [ text draft.name ]
        , td [] [ text draft.phone ]
        , td [] [ text draft.email ]
        , td [] [ text draft.address ]
        , td []
            [ button
                [ type_ "button", class "btn btn-danger", disabled saving
                , stopPropagationOn "click" (Json.Decode.succeed ( ConfirmDelete contact.id, True ))
                ]
                [ text "Delete" ]
            ]
        ]


panelView : Model -> Html Msg
panelView model =
    case model.panel of
        Closed ->
            text ""

        Editing identifier draft ->
            form [ class "form-section", onSubmit Apply ]
                [ h3 [] [ text (if identifier == Nothing then "Add Contact" else "Edit Contact") ]
                , errorMessage model.mutationError
                , field input "Name" draft.name model.saving (\entry -> ChangeDraft { draft | name = entry })
                , field input "Phone" draft.phone model.saving (\entry -> ChangeDraft { draft | phone = entry })
                , field input "Email" draft.email model.saving (\entry -> ChangeDraft { draft | email = entry })
                , field textarea "Address" draft.address model.saving (\entry -> ChangeDraft { draft | address = entry })
                , button [ type_ "submit", class "btn btn-primary", disabled model.saving ] [ text "Save" ]
                , action "btn-neutral" "Cancel" model.saving Cancel
                ]

        Confirming _ ->
            div [ class "confirm-section" ]
                [ h3 [] [ text "Confirm Delete" ]
                , p [] [ text "Are you sure you want to delete this contact?" ]
                , errorMessage model.mutationError
                , action "btn-danger" "Yes, Delete" model.saving Apply
                , action "btn-neutral" "Cancel" model.saving Cancel
                ]


field : (List (Html.Attribute Msg) -> List (Html Msg) -> Html Msg) -> String -> String -> Bool -> (String -> Msg) -> Html Msg
field control caption entry saving change =
    let
        fieldId =
            "contact-" ++ String.toLower caption
    in
    div [ class "form-group" ]
        [ label [ for fieldId ] [ text caption ]
        , control [ id fieldId, value entry, disabled saving, onInput change ] []
        ]


action : String -> String -> Bool -> Msg -> Html Msg
action appearance caption inactive message =
    button [ type_ "button", class ("btn " ++ appearance), disabled inactive, onClick message ] [ text caption ]


errorMessage : String -> Html Msg
errorMessage message =
    if String.isEmpty message then
        text ""

    else
        p [ class "error", attribute "role" "alert" ] [ text message ]
