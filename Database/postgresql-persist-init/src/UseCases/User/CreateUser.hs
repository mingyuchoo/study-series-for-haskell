{-# LANGUAGE FlexibleContexts #-}

module UseCases.User.CreateUser
    ( CreateUserRequest (..)
    , CreateUserResponse (..)
    , CreateUserUseCase (..)
    , createUser
    ) where

import           Data.Text                          (Text)

import           Domain.Entities.User
import           Domain.Repositories.UserRepository

-- Use case input/output DTOs
data CreateUserRequest = CreateUserRequest { crName       :: Text
                                           , crEmail      :: Text
                                           , crAge        :: Int
                                           , crOccupation :: Text
                                           }
     deriving (Eq, Show)

data CreateUserResponse = CreateUserResponse { crUserId :: UserId
                                             }
     deriving (Eq, Show)

-- Use case interface
class (Monad m) => CreateUserUseCase m where
  executeCreateUser :: CreateUserRequest -> m (Either Text CreateUserResponse)

-- Use case implementation
createUser
  :: (UserRepository m) => CreateUserRequest -> m (Either Text CreateUserResponse)
createUser req = do
  -- Check if user already exists
  existingUser <- findUserByEmail (UserEmail $ crEmail req)
  case existingUser of
    Just _ -> return $ Left "User with this email already exists"
    Nothing -> do
      -- Create and validate user
      case mkUser (crName req) (crEmail req) (crAge req) (crOccupation req) of
        Left err -> return $ Left err
        Right user -> do
          -- Save user
          userId <- saveUser user
          return $ Right $ CreateUserResponse userId
