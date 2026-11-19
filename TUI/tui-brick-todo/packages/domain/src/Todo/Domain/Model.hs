module Todo.Domain.Model
  ( TodoId
  , Todo (..)
  , TodoFields
  , ValidationError (..)
  , action
  , subject
  , indirectObject
  , directObject
  , normalize
  , normalizeOptional
  , validateFields
  ) where

import TodoStatus (TodoStatusType)

type TodoId = Int

data TodoFields = TodoFields !String !(Maybe String) !(Maybe String) !(Maybe String)
  deriving (Eq, Show)

action :: TodoFields -> String
action (TodoFields value _ _ _) = value

subject :: TodoFields -> Maybe String
subject (TodoFields _ value _ _) = value

indirectObject :: TodoFields -> Maybe String
indirectObject (TodoFields _ _ value _) = value

directObject :: TodoFields -> Maybe String
directObject (TodoFields _ _ _ value) = value

data ValidationError = EmptyAction
  deriving (Eq, Show)

data Todo = Todo
  { identifier :: !TodoId
  , fields :: !TodoFields
  , status :: !TodoStatusType
  , createdAt :: !String
  , changedAt :: !(Maybe String)
  }
  deriving (Eq, Show)

normalize :: String -> String
normalize = unwords . words

normalizeOptional :: Maybe String -> Maybe String
normalizeOptional value = case normalize <$> value of
  Just "" -> Nothing
  normalized -> normalized

validateFields
  :: String
  -> Maybe String
  -> Maybe String
  -> Maybe String
  -> Either ValidationError TodoFields
validateFields text subj indirect direct =
  case normalize text of
    "" -> Left EmptyAction
    normalized ->
      Right $
        TodoFields
          normalized
          (normalizeOptional subj)
          (normalizeOptional indirect)
          (normalizeOptional direct)
