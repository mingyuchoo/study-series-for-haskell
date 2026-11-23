module Application.UseCases
  ( createUserUC
  , deleteUserUC
  , getUserUC
  , initializeDatabase
  , listAllUsers
  , seedSampleData
  , updateUserUC
  ) where

import Domain.Model (User (..))
import Domain.Repository (UserRepository (..))

initializeDatabase :: (UserRepository m, Applicative m) => m Bool
initializeDatabase = pure True

seedSampleData :: (UserRepository m, Monad m) => m Bool
seedSampleData = do
  _ <- createUser (User 1 "Jacob")
  _ <- updateUser (User 1 "Tomas")
  pure True

listAllUsers :: (UserRepository m) => m [User]
listAllUsers = listUsers

createUserUC :: (UserRepository m) => User -> m Bool
createUserUC = createUser

updateUserUC :: (UserRepository m) => User -> m Bool
updateUserUC = updateUser

deleteUserUC :: (UserRepository m) => Int -> m Bool
deleteUserUC = deleteUser

getUserUC :: (UserRepository m) => Int -> m (Maybe User)
getUserUC = retrieveUser
