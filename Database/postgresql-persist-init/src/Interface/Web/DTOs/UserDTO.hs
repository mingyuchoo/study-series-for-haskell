{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE OverloadedStrings #-}

module Interface.Web.DTOs.UserDTO
    ( CreateUserRequestDTO (..)
    , CreateUserResponseDTO (..)
    , UpdateUserRequestDTO (..)
    , UserResponseDTO (..)
    , createUserRequestToUseCase
    , updateUserRequestToUseCase
    , userToResponseDTO
    ) where

import           Data.Aeson
import           Data.Int                 (Int64)
import           Data.Text                (Text)

import           Domain.Entities.User

import           GHC.Generics             (Generic)

import qualified UseCases.User.CreateUser as UC
import qualified UseCases.User.UpdateUser as UU

-- Response DTOs
data UserResponseDTO = UserResponseDTO { userId         :: Int64
                                       , userName       :: Text
                                       , userEmail      :: Text
                                       , userAge        :: Int
                                       , userOccupation :: Text
                                       }
     deriving (Eq, Generic, Show)

instance ToJSON UserResponseDTO where
  toJSON (UserResponseDTO uid name email age occupation) =
    object
      [ "id" .= uid
      , "name" .= name
      , "email" .= email
      , "age" .= age
      , "occupation" .= occupation
      ]

instance FromJSON UserResponseDTO where
  parseJSON = withObject "UserResponseDTO" $ \o ->
    UserResponseDTO
      <$> o .: "id"
      <*> o .: "name"
      <*> o .: "email"
      <*> o .: "age"
      <*> o .: "occupation"

-- Request DTOs
data CreateUserRequestDTO = CreateUserRequestDTO { crName       :: Text
                                                 , crEmail      :: Text
                                                 , crAge        :: Int
                                                 , crOccupation :: Text
                                                 }
     deriving (Eq, Generic, Show)

instance ToJSON CreateUserRequestDTO where
  toJSON (CreateUserRequestDTO name email age occupation) =
    object
      [ "name" .= name
      , "email" .= email
      , "age" .= age
      , "occupation" .= occupation
      ]

instance FromJSON CreateUserRequestDTO where
  parseJSON = withObject "CreateUserRequestDTO" $ \o ->
    CreateUserRequestDTO
      <$> o .: "name"
      <*> o .: "email"
      <*> o .: "age"
      <*> o .: "occupation"

data CreateUserResponseDTO = CreateUserResponseDTO { crUserId :: Int64
                                                   }
     deriving (Eq, Generic, Show)

instance ToJSON CreateUserResponseDTO where
  toJSON (CreateUserResponseDTO uid) = object ["id" .= uid]

instance FromJSON CreateUserResponseDTO where
  parseJSON = withObject "CreateUserResponseDTO" $ \o ->
    CreateUserResponseDTO
      <$> o .: "id"

data UpdateUserRequestDTO = UpdateUserRequestDTO { urName       :: Maybe Text
                                                 , urEmail      :: Maybe Text
                                                 , urAge        :: Maybe Int
                                                 , urOccupation :: Maybe Text
                                                 }
     deriving (Eq, Generic, Show)

instance ToJSON UpdateUserRequestDTO where
  toJSON (UpdateUserRequestDTO name email age occupation) =
    object
      [ "name" .= name
      , "email" .= email
      , "age" .= age
      , "occupation" .= occupation
      ]

instance FromJSON UpdateUserRequestDTO where
  parseJSON = withObject "UpdateUserRequestDTO" $ \o ->
    UpdateUserRequestDTO
      <$> o .:? "name"
      <*> o .:? "email"
      <*> o .:? "age"
      <*> o .:? "occupation"

-- Conversion functions
userToResponseDTO :: User -> UserResponseDTO
userToResponseDTO ( User
                      (Just (UserId uid))
                      (UserName name)
                      (UserEmail email)
                      (UserAge age)
                      (UserOccupation occupation)
                    ) =
  UserResponseDTO uid name email age occupation
userToResponseDTO (User Nothing _ _ _ _) =
  error "Cannot convert user without ID to response DTO"

createUserRequestToUseCase :: CreateUserRequestDTO -> UC.CreateUserRequest
createUserRequestToUseCase dto =
  UC.CreateUserRequest
    { UC.crName = crName dto
    , UC.crEmail = crEmail dto
    , UC.crAge = crAge dto
    , UC.crOccupation = crOccupation dto
    }

updateUserRequestToUseCase :: Int64 -> UpdateUserRequestDTO -> UU.UpdateUserRequest
updateUserRequestToUseCase uid dto =
  UU.UpdateUserRequest
    { UU.urUserId = UserId uid
    , UU.urName = urName dto
    , UU.urEmail = urEmail dto
    , UU.urAge = urAge dto
    , UU.urOccupation = urOccupation dto
    }
