module Application.Management exposing (Effect(..), LoadState(..), Model, Msg(..), Notice, Pending(..), initial, isBusy, update)

import Domain.User exposing (User, validateName)


type LoadState
    = Loading
    | Loaded
    | Failed String


type Pending
    = Creating
    | Updating Int
    | Deleting Int


type alias Notice =
    { message : String, isError : Bool }


type alias Model =
    { users : List User
    , loadState : LoadState
    , selected : Maybe User
    , name : String
    , nameError : Maybe String
    , search : String
    , pending : Maybe Pending
    , deletion : Maybe User
    , notice : Maybe Notice
    , menuOpen : Bool
    }


type Msg
    = UsersLoaded (Result String (List User))
    | NameChanged String
    | SearchChanged String
    | Submit
    | SelectUser User
    | CancelEdit
    | RequestDelete User
    | CancelDelete
    | ConfirmDelete
    | UserSaved (Result String User)
    | UserDeleted (Result String ())
    | Refresh
    | DismissNotice
    | StartCreate
    | ToggleMenu
    | CloseMenu
    | EditorFocused (Result String ())


type Effect
    = LoadUsers
    | SaveUser (Maybe Int) String
    | RemoveUser Int
    | FocusEditor


initial : ( Model, List Effect )
initial =
    ( { users = []
      , loadState = Loading
      , selected = Nothing
      , name = ""
      , nameError = Nothing
      , search = ""
      , pending = Nothing
      , deletion = Nothing
      , notice = Nothing
      , menuOpen = False
      }
    , [ LoadUsers ]
    )


isBusy : Model -> Bool
isBusy model =
    model.pending /= Nothing || model.loadState == Loading


update : Msg -> Model -> ( Model, List Effect )
update message model =
    case message of
        UsersLoaded result ->
            case result of
                Ok users ->
                    ( { model | users = users, loadState = Loaded }, [] )

                Err problem ->
                    ( { model | loadState = Failed problem }, [] )

        SearchChanged query ->
            ( { model | search = query, deletion = Nothing }, [] )

        ToggleMenu ->
            ( { model | menuOpen = not model.menuOpen }, [] )

        CloseMenu ->
            ( { model | menuOpen = False }, [] )

        EditorFocused result ->
            case result of
                Ok () ->
                    ( model, [] )

                Err problem ->
                    ( { model | notice = Just { message = problem, isError = True } }, [] )

        DismissNotice ->
            ( { model | notice = Nothing }, [] )

        UserSaved result ->
            case model.pending of
                Just Creating ->
                    finishSave "User created." result model

                Just (Updating _) ->
                    finishSave "Changes saved." result model

                _ ->
                    ( model, [] )

        UserDeleted result ->
            case model.pending of
                Just (Deleting identifier) ->
                    case result of
                        Ok () ->
                            let
                                next =
                                    if Maybe.map .id model.selected == Just identifier then
                                        clearEditor model

                                    else
                                        model
                            in
                            reload "User deleted." { next | deletion = Nothing }

                        Err problem ->
                            withError problem model

                _ ->
                    ( model, [] )

        _ ->
            if isBusy model then
                ( model, [] )

            else
                updateIdle message model


updateIdle : Msg -> Model -> ( Model, List Effect )
updateIdle message model =
    case message of
        NameChanged name ->
            ( { model | name = name, nameError = Nothing }, [] )

        Submit ->
            if model.deletion /= Nothing then
                ( model, [] )

            else
                case validateName model.name of
                    Err problem ->
                        ( { model | nameError = Just problem }, [] )

                    Ok name ->
                        ( { model
                            | name = name
                            , pending = Just (Maybe.map (.id >> Updating) model.selected |> Maybe.withDefault Creating)
                            , nameError = Nothing
                            , notice = Nothing
                          }
                        , [ SaveUser (Maybe.map .id model.selected) name ]
                        )

        SelectUser user ->
            ( { model | selected = Just user, name = user.name, nameError = Nothing, deletion = Nothing }, [ FocusEditor ] )

        StartCreate ->
            ( clearEditor { model | deletion = Nothing, menuOpen = False }, [ FocusEditor ] )

        CancelEdit ->
            ( clearEditor model, [] )

        RequestDelete user ->
            ( { model | deletion = Just user, notice = Nothing }, [] )

        CancelDelete ->
            ( { model | deletion = Nothing }, [] )

        ConfirmDelete ->
            case model.deletion of
                Just user ->
                    ( { model | pending = Just (Deleting user.id), notice = Nothing }, [ RemoveUser user.id ] )

                Nothing ->
                    ( model, [] )

        Refresh ->
            ( { model | loadState = Loading, deletion = Nothing }, [ LoadUsers ] )

        _ ->
            ( model, [] )


clearEditor : Model -> Model
clearEditor model =
    { model | selected = Nothing, name = "", nameError = Nothing }


finishSave : String -> Result String User -> Model -> ( Model, List Effect )
finishSave message result model =
    case result of
        Ok _ ->
            reload message (clearEditor model)

        Err problem ->
            withError problem model


reload : String -> Model -> ( Model, List Effect )
reload message model =
    ( { model | pending = Nothing, loadState = Loading, notice = Just { message = message, isError = False } }, [ LoadUsers ] )


withError : String -> Model -> ( Model, List Effect )
withError problem model =
    ( { model | pending = Nothing, notice = Just { message = problem, isError = True } }, [] )
