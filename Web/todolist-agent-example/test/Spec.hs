module Main (main) where

import Test.Hspec (hspec)
import Todo.Application.CompleteTodoSpec qualified
import Todo.Application.CreateTodoSpec qualified
import Todo.Application.DeleteTodoSpec qualified
import Todo.Domain.TodoSpec qualified
import Todo.Interface.HTTP.TodoApiSpec qualified

main :: IO ()
main = hspec $ do
    Todo.Domain.TodoSpec.spec
    Todo.Application.CreateTodoSpec.spec
    Todo.Application.CompleteTodoSpec.spec
    Todo.Application.DeleteTodoSpec.spec
    Todo.Interface.HTTP.TodoApiSpec.spec
