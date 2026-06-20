{-# LANGUAGE NamedFieldPuns  #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ViewPatterns    #-}

module Lib
  where

import Data.Char (toUpper)

-- | someFunc
someFunc :: IO ()
someFunc = return ()

-- | firstOrEmpty
firstOrEmpty :: [[Char]] -> [Char]
firstOrEmpty lst =
  if not (null lst)
    then head lst
    else "empty"

-- | (+++)
lst1 +++ lst2 =
  if null lst1
    then lst2
    else (head lst1) : (tail lst1 +++ lst2)

-- | reverse2
reverse2 list =
  if null list
    then []
    else reverse2 (tail list) +++ [head list]

-- | maxmin
maxmin [x] = (x, x)
maxmin (x : xs) =
  ( if x > xs_max then x else xs_max
  , if x < xs_min then x else xs_min
  )
  where
    (xs_max, xs_min) = maxmin xs

-- | Client
data Client = GovOrg String
            | Company String Integer Person String
            | Individual Person Bool
  deriving (Show)

-- | ClientR
data ClientR = GovOrgR
  { clientRName :: String
  }
             | CompanyR
  { clientRName :: String
  , companyId   :: Integer
  , person      :: PersonR
  , duty        :: String
  }
             | IndividualR
  { person :: PersonR
  }
  deriving (Show)

-- | Person
data Person = Person String String Gender
  deriving (Show)

-- | PersonR
data PersonR = PersonR
  { firstName :: String
  , lastName  :: String
  }
  deriving (Show)

-- | Gender
data Gender = Male | Female | Unknown
  deriving (Show)

-- | clientName
clientName :: Client -> String
clientName client =
  case client of
    GovOrg name                     -> name
    Company name _ _ _              -> name
    Individual (Person fNm lNm _) _ -> fNm ++ " " ++ lNm

-- | companyName
companyName :: Client -> Maybe String
companyName client =
  case client of
    Company name _ _ _ -> Just name
    _                  -> Nothing

-- | responsibility
responsibility :: Client -> String
responsibility (Company _ _ _ r) = r
responsibility _                 = "Unknown"

-- | view pattern (function -> pattern)
specialClient :: Client -> Bool
specialClient (clientName -> "Mr.Alejandro") = True
specialClient (responsibility -> "Director") = True
specialClient _                              = False

-- | sorted
sorted :: [Integer] -> Bool
sorted []              = True
sorted [_]             = True
sorted (x : r@(y : _)) = x < y && sorted r

-- | Normal Usage (NOT NamedFieldPuns, Or NOT RecordWildCards)
greet0 :: ClientR -> String
greet0 IndividualR {person = PersonR {firstName = fn}} = "Hi, " ++ fn
greet0 CompanyR {clientRName = c}                      = "Hi, " ++ c
greet0 GovOrgR {}                                      = "Welcome"

-- | NamedFieldPuns
greet1 :: ClientR -> String
greet1 IndividualR {person = PersonR {firstName}} = "Hi, " ++ firstName
greet1 CompanyR {clientRName}                     = "Hi, " ++ clientRName
greet1 GovOrgR {}                                 = "Welcome"

-- | RecordWhildCards
greet2 :: ClientR -> String
greet2 IndividualR {person = PersonR {..}} = "Hi, " ++ firstName
greet2 CompanyR {..}                       = "Hi, " ++ clientRName
greet2 GovOrgR {}                          = "Welcome"

-- | nameInCapitals
nameInCapitals :: PersonR -> PersonR
nameInCapitals p@(PersonR {firstName = initial : rest}) =
  let newName = (toUpper initial) : rest
   in p {firstName = newName}

nameInCapitials p@(PersonR {firstName = ""}) = p

-- | ConnType
data ConnType = TCP | UDP

data UseProxy = NoProxy
              | Proxy String
data TimeOut = NoTimeOut
             | TimeOut Integer
