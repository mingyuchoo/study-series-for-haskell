module UserTest exposing (tests)

import Domain.User exposing (filterUsers, validateName)
import Expect
import Test exposing (Test, describe, test)


tests : Test
tests =
    describe "User rules"
        [ test "rejects whitespace-only names" <|
            \_ -> validateName "  \n " |> Expect.err
        , test "trims names before saving" <|
            \_ -> validateName "  Ada Lovelace  " |> Expect.equal (Ok "Ada Lovelace")
        , test "finds names without case sensitivity" <|
            \_ -> filterUsers " ADA " [ { id = 1, name = "Ada Lovelace" }, { id = 2, name = "Grace Hopper" } ] |> Expect.equal [ { id = 1, name = "Ada Lovelace" } ]
        , test "finds users by identifier" <|
            \_ -> filterUsers "42" [ { id = 42, name = "Grace" }, { id = 3, name = "Ada" } ] |> Expect.equal [ { id = 42, name = "Grace" } ]
        , test "empty search returns all users" <|
            \_ -> filterUsers " " [ { id = 1, name = "Ada" } ] |> Expect.equal [ { id = 1, name = "Ada" } ]
        ]
