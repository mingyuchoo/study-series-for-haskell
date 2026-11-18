module Presentation.Directory exposing (view)

import Application.Management exposing (LoadState(..), Model, Msg(..), Pending(..), isBusy)
import Domain.User exposing (User, filterUsers)
import Html exposing (Html, a, button, caption, div, footer, h1, h2, h3, input, label, main_, p, section, span, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (attribute, class, disabled, href, id, scope, type_, value)
import Html.Events exposing (onClick, onInput)
import Presentation.Editor as Editor
import Presentation.Navigation as Navigation


view : Model -> Html Msg
view model =
    div []
        [ a [ class "skip-link", href "#directory" ] [ text "Skip to directory" ]
        , Navigation.view model
        , main_ [ class "page-container" ]
            [ viewHero model
            , viewNotice model
            , div [ class "workspace-grid" ] [ viewDirectory model, Editor.view model ]
            , section [ class "closing-note", attribute "aria-label" "About this workspace" ]
                [ span [ class "closing-number" ] [ text "01 / PEOPLE FIRST" ]
                , p [] [ text "The beginning of something good.", span [] [ text "Keep your people close, and your workspace simple." ] ]
                ]
            ]
        , footer [ class "site-footer" ]
            [ div [ class "page-container footer-content" ]
                [ div [] [ span [ class "footer-wordmark" ] [ text "folio" ], p [] [ text "A thoughtful space for your people." ] ]
                , a [ href "#directory" ] [ text "Back to your people ↑" ]
                ]
            ]
        ]


viewHero : Model -> Html Msg
viewHero model =
    section [ class "hero", attribute "aria-labelledby" "page-title" ]
        [ div [ class "hero-copy" ]
            [ div [ class "section-eyebrow" ] [ span [ class "eyebrow-line" ] [], text "A LITTLE MORE CONNECTED" ]
            , h1 [ id "page-title" ] [ text "Good work starts", Html.br [] [], text "with good people." ]
            , p [ class "hero-description" ] [ text "A place for everyone in your workspace. Bring people together, keep things in order, and make room for what’s next." ]
            ]
        , div [ class "overview-card" ]
            [ div [ class "overview-top" ] [ span [ class "section-eyebrow" ] [ text "YOUR PEOPLE" ], span [ class "overview-symbol", attribute "aria-hidden" "true" ] [ text "✳" ] ]
            , div [ class "overview-number" ]
                [ text
                    (if model.loadState == Loaded then
                        String.fromInt (List.length model.users)

                     else
                        "—"
                    )
                ]
            , p [ class "overview-caption" ] [ text "Individual people. Shared possibilities." ]
            , div [ class "overview-bottom" ]
                [ span [ class "status-dot", attribute "aria-hidden" "true" ] []
                , text
                    (case model.loadState of
                        Loading ->
                            "Updating your directory"

                        Failed _ ->
                            "Directory needs a refresh"

                        Loaded ->
                            "Your directory, up to date"
                    )
                ]
            ]
        ]


viewNotice : Model -> Html Msg
viewNotice model =
    case model.notice of
        Nothing ->
            text ""

        Just notice ->
            div
                [ class
                    ("notice "
                        ++ (if notice.isError then
                                "notice-error"

                            else
                                "notice-success"
                           )
                    )
                , attribute "role"
                    (if notice.isError then
                        "alert"

                     else
                        "status"
                    )
                ]
                [ span [] [ text notice.message ]
                , button [ type_ "button", class "text-button", attribute "aria-label" "Dismiss notification", onClick DismissNotice ] [ text "×" ]
                ]


viewDirectory : Model -> Html Msg
viewDirectory model =
    let
        visible =
            filterUsers model.search model.users
    in
    section
        [ class "directory"
        , id "directory"
        , attribute "aria-labelledby" "directory-title"
        , attribute "aria-busy"
            (if isBusy model then
                "true"

             else
                "false"
            )
        ]
        [ div [ class "directory-heading" ]
            [ div [ class "heading-with-count" ] [ h2 [ id "directory-title" ] [ text "Your people" ], span [ class "count-badge" ] [ text (String.fromInt (List.length model.users)) ] ]
            , button [ type_ "button", class "button button-secondary", onClick Refresh, disabled (isBusy model) ] [ span [ attribute "aria-hidden" "true" ] [ text "↻" ], text "Refresh" ]
            ]
        , div [ class "search-field" ]
            [ label [ Html.Attributes.for "people-search", class "visually-hidden" ] [ text "Search people" ]
            , span [ class "search-symbol", attribute "aria-hidden" "true" ] [ text "⌕" ]
            , input [ id "people-search", type_ "search", Html.Attributes.placeholder "Find someone by name or ID…", value model.search, onInput SearchChanged ] []
            ]
        , case model.loadState of
            Loading ->
                div [ class "empty-state", attribute "role" "status" ] [ span [ class "loading-mark", attribute "aria-hidden" "true" ] [ text "✳" ], h3 [] [ text "Gathering your people…" ], p [] [ text "Your directory will be here in a moment." ] ]

            Failed problem ->
                div [ class "empty-state", attribute "role" "alert" ] [ h3 [] [ text "Let’s try that again." ], p [] [ text problem ], button [ type_ "button", class "button button-primary", onClick Refresh ] [ text "Try again" ] ]

            Loaded ->
                if List.isEmpty visible then
                    viewEmpty model

                else
                    table [ class "people-table" ]
                        [ caption [ class "visually-hidden" ] [ text "People in your workspace" ]
                        , thead [] [ tr [] [ th [ scope "col" ] [ text "PERSON" ], th [ scope "col", class "id-column" ] [ text "USER ID" ], th [ scope "col", class "actions-heading" ] [ text "ACTIONS" ] ] ]
                        , tbody [] (List.map (viewUser model) visible)
                        ]
        , div [ class "directory-footnote", attribute "role" "status" ]
            [ text
                (if model.loadState == Loaded then
                    String.fromInt (List.length visible) ++ " of " ++ String.fromInt (List.length model.users) ++ " people"

                 else
                    "Your workspace directory"
                )
            , span [] [ text "A place for everyone." ]
            ]
        ]


viewEmpty : Model -> Html Msg
viewEmpty model =
    div [ class "empty-state" ]
        [ span [ class "empty-mark", attribute "aria-hidden" "true" ] [ text "✳" ]
        , h3 []
            [ text
                (if List.isEmpty model.users then
                    "Every team starts with someone."

                 else
                    "No one by that name. Yet."
                )
            ]
        , p []
            [ text
                (if List.isEmpty model.users then
                    "Add your first person using the form. Good things grow from here."

                 else
                    "Try another name or user ID to find who you’re looking for."
                )
            ]
        , if String.trim model.search /= "" then
            button [ type_ "button", class "button button-secondary", onClick (SearchChanged "") ] [ text "Clear search" ]

          else
            text ""
        ]


viewUser : Model -> User -> Html Msg
viewUser model user =
    let
        confirming =
            Maybe.map .id model.deletion == Just user.id

        selected =
            Maybe.map .id model.selected == Just user.id
    in
    tr
        [ class
            (if selected then
                "selected-row"

             else
                ""
            )
        ]
        [ td [] [ div [ class "person-cell" ] [ span [ class ("avatar avatar-" ++ String.fromInt (modBy 3 user.id)), attribute "aria-hidden" "true" ] [ text (String.left 1 (String.toUpper user.name)) ], span [ class "person-name" ] [ text user.name ] ] ]
        , td [ class "id-column user-id" ] [ text ("#" ++ String.padLeft 3 '0' (String.fromInt user.id)) ]
        , td [ class "row-actions" ]
            [ if confirming then
                div [ class "delete-confirmation", attribute "role" "group", attribute "aria-label" ("Confirm deletion of " ++ user.name) ]
                    [ span [] [ text "Delete this person?" ]
                    , button [ class "text-button", type_ "button", onClick CancelDelete, disabled (isBusy model) ] [ text "Keep user" ]
                    , button [ class "text-button danger", type_ "button", onClick ConfirmDelete, disabled (isBusy model) ]
                        [ text
                            (if model.pending == Just (Deleting user.id) then
                                "Deleting…"

                             else
                                "Delete permanently"
                            )
                        ]
                    ]

              else
                div [ class "action-buttons" ]
                    [ button [ type_ "button", class "text-button", attribute "aria-label" ("Edit " ++ user.name), onClick (SelectUser user), disabled (isBusy model) ] [ text "Edit", span [ attribute "aria-hidden" "true" ] [ text "↗" ] ]
                    , button [ type_ "button", class "text-button delete-button", attribute "aria-label" ("Delete " ++ user.name), onClick (RequestDelete user), disabled (isBusy model) ] [ text "Delete" ]
                    ]
            ]
        ]
