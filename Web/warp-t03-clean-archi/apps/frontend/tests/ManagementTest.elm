module ManagementTest exposing (tests)

import Application.Management exposing (Effect(..), LoadState(..), Msg(..), initial, update)
import Expect
import Test exposing (Test, describe, test)


ready =
    initial |> Tuple.first |> update (UsersLoaded (Ok [ { id = 1, name = "Ada" } ])) |> Tuple.first


tests : Test
tests =
    describe "User management"
        [ test "requests users on startup" <|
            \_ -> initial |> Tuple.second |> Expect.equal [ LoadUsers ]
        , test "invalid names never cause HTTP effects" <|
            \_ -> ready |> update Submit |> Tuple.second |> Expect.equal []
        , test "submits trimmed names" <|
            \_ -> ready |> update (NameChanged "  Grace  ") |> Tuple.first |> update Submit |> Tuple.second |> Expect.equal [ SaveUser Nothing "Grace" ]
        , test "prevents duplicate submissions" <|
            \_ -> ready |> update (NameChanged "Grace") |> Tuple.first |> update Submit |> Tuple.first |> update Submit |> Tuple.second |> Expect.equal []
        , test "edits the selected user" <|
            \_ -> ready |> update (SelectUser { id = 1, name = "Ada" }) |> Tuple.first |> update (NameChanged "Augusta") |> Tuple.first |> update Submit |> Tuple.second |> Expect.equal [ SaveUser (Just 1) "Augusta" ]
        , test "deletion requires confirmation" <|
            \_ -> ready |> update (RequestDelete { id = 1, name = "Ada" }) |> Tuple.second |> Expect.equal []
        , test "confirmed deletion targets the selected user" <|
            \_ -> ready |> update (RequestDelete { id = 1, name = "Ada" }) |> Tuple.first |> update ConfirmDelete |> Tuple.second |> Expect.equal [ RemoveUser 1 ]
        , test "cancelling deletion sends no request" <|
            \_ -> ready |> update (RequestDelete { id = 1, name = "Ada" }) |> Tuple.first |> update CancelDelete |> Tuple.first |> update ConfirmDelete |> Tuple.second |> Expect.equal []
        , test "save failures preserve form input for retry" <|
            \_ -> ready |> update (NameChanged "Grace") |> Tuple.first |> update Submit |> Tuple.first |> update (UserSaved (Err "Unavailable")) |> Tuple.first |> .name |> Expect.equal "Grace"
        , test "successful writes refresh server data" <|
            \_ -> ready |> update (NameChanged "Grace") |> Tuple.first |> update Submit |> Tuple.first |> update (UserSaved (Ok { id = 2, name = "Grace" })) |> Tuple.second |> Expect.equal [ LoadUsers ]
        , test "load errors can be retried" <|
            \_ -> initial |> Tuple.first |> update (UsersLoaded (Err "Offline")) |> Tuple.first |> update Refresh |> Tuple.second |> Expect.equal [ LoadUsers ]
        , test "cannot change selection during a write" <|
            \_ -> ready |> update (NameChanged "Grace") |> Tuple.first |> update Submit |> Tuple.first |> update (SelectUser { id = 1, name = "Ada" }) |> Tuple.first |> .selected |> Expect.equal Nothing
        , test "searching clears deletion confirmation so hidden rows cannot block the form" <|
            \_ -> ready |> update (RequestDelete { id = 1, name = "Ada" }) |> Tuple.first |> update (SearchChanged "Nobody") |> Tuple.first |> .deletion |> Expect.equal Nothing
        , test "refresh clears deletion confirmation when users might disappear" <|
            \_ -> ready |> update (RequestDelete { id = 1, name = "Ada" }) |> Tuple.first |> update Refresh |> Tuple.first |> .deletion |> Expect.equal Nothing
        , test "selecting a person requests focus on their editable name" <|
            \_ -> ready |> update (SelectUser { id = 1, name = "Ada" }) |> Tuple.second |> Expect.equal [ FocusEditor ]
        , test "the add shortcut exits edit mode and clears the old name" <|
            \_ -> ready |> update (SelectUser { id = 1, name = "Ada" }) |> Tuple.first |> update StartCreate |> Tuple.first |> (\model -> ( model.selected, model.name )) |> Expect.equal ( Nothing, "" )
        , test "search during a failed deletion cannot leave an invisible confirmation" <|
            \_ -> ready |> update (RequestDelete { id = 1, name = "Ada" }) |> Tuple.first |> update ConfirmDelete |> Tuple.first |> update (SearchChanged "Nobody") |> Tuple.first |> update (UserDeleted (Err "Unavailable")) |> Tuple.first |> .deletion |> Expect.equal Nothing
        ]
