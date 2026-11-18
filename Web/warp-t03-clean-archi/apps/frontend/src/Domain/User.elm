module Domain.User exposing (User, filterUsers, validateName)


type alias User =
    { id : Int, name : String }


validateName : String -> Result String String
validateName value =
    let
        name =
            String.trim value
    in
    if String.isEmpty name then
        Err "Please enter a name."

    else
        Ok name


filterUsers : String -> List User -> List User
filterUsers query users =
    let
        normalized =
            String.toLower (String.trim query)
    in
    List.filter
        (\user ->
            String.contains normalized (String.toLower user.name)
                || String.contains normalized (String.fromInt user.id)
        )
        users
