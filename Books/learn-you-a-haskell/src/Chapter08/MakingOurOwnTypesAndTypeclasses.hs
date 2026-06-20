module Chapter08.MakingOurOwnTypesAndTypeclasses
  where

import Data.Kind (Constraint, Type)
import Data.Map qualified as Map

type Point :: Type
data Point = Point Float Float
  deriving (Show)

type Shape :: Type
data Shape = Circle Point Float
           | Rectangle Point Point
  deriving (Show)

-- | area
area :: Shape -> Float -- function signature declaration
area (Circle _ r)                            = pi * r ^ 2
area (Rectangle (Point x1 y1) (Point x2 y2)) = (abs $ x2 - x1) * (abs $ y2 - y1)

-- | nudge
nudge :: Shape -> Float -> Float -> Shape
nudge (Circle (Point x y) r) a b = Circle (Point (x + a) (y + b)) r
nudge (Rectangle (Point x1 y1) (Point x2 y2)) a b =
  Rectangle (Point (x1 + a) (y1 + b)) (Point (x2 + a) (y2 + b))

-- | baseCircle
baseCircle :: Float -> Shape
baseCircle r = Circle (Point 0 0) r

-- | baseRect
baseRect :: Float -> Float -> Shape
baseRect width height = Rectangle (Point 0 0) (Point width height)

type Person :: Type
data Person = Person String String Int Float String String
  deriving (Show)

-- firstName :: Person -> String
-- firstName (Person firstname _ _ _ _ _) = firstname
--
-- lastName :: Person -> String
-- lastName (Person _ lastname _ _ _ _) = lastname
--
-- age :: Person -> Int
-- age (Person _ _ age _ _ _) = age
--
-- height :: Person -> Float
-- height (Person _ _ _ height _ _) = height
--
-- phoneNumber :: Person -> String
-- phoneNumber (Person _ _ _ _ number _) = number
--
-- flavor :: Person -> String
-- flavor (Person _ _ _ _ _ flavor) = flavor

type Person2 :: Type
data Person2 = Person2
  { firstName2   :: String
  , lastName2    :: String
  , age2         :: Int
  , height2      :: Float
  , phoneNumber2 :: String
  , flavor2      :: String
  }
  deriving (Show)

type Car :: Type
data Car = Car
  { company :: String
  , model   :: String
  , year    :: Int
  }
  deriving (Show)

-- |
-- tellCar :: Car -> String
-- tellCar (Car { company = c, model = m, year = y}) =
--   "This " ++ c ++ " " ++ m ++ " was made in " ++ show y
type Car2 :: Type -> Type -> Type -> Type
data Car2 a b c = Car2
  { company2 :: a
  , model2   :: b
  , year2    :: c
  }
  deriving (Show)

tellCar2 :: (Show a) => Car2 String String a -> String
tellCar2 (Car2 {company2 = c, model2 = m, year2 = y}) =
  "This " ++ c ++ " " ++ m ++ " was made in " ++ show y

type Vector :: Type -> Type
data Vector a = Vector a a a
  deriving (Show)

vplus :: (Num t) => Vector t -> Vector t -> Vector t
(Vector i j k) `vplus` (Vector l m n) = Vector (i + l) (j + m) (k + n)

vectMult :: (Num t) => Vector t -> t -> Vector t
(Vector i j k) `vectMult` m = Vector (i * m) (j * m) (k * m)

scalarMult :: (Num t) => Vector t -> Vector t -> t
(Vector i j k) `scalarMult` (Vector l m n) = i * l + j * m + k * m

type Person3 :: Type
data Person3 = Person3
  { firstName3 :: String
  , lastName3  :: String
  , age3       :: Int
  }
  deriving (Eq)

type Person4 :: Type
data Person4 = Person4
  { firstName4 :: String
  , lastName4  :: String
  , age4       :: Int
  }
  deriving (Eq, Read, Show)

type Day :: Type
data Day = Monday | Tuesday | Wednesday | Thursday | Friday | Saturday | Sunday
  deriving (Bounded, Enum, Eq, Ord, Read, Show)

-- |
-- Phone Book
type Name :: Type
type Name = String

type PhoneNumber :: Type
type PhoneNumber = String

type PhoneBook :: Type
type PhoneBook = [(Name, PhoneNumber)]

phoneBook :: PhoneBook
phoneBook =
  [ ("betty", "555-2938")
  , ("bonnie", "452-2928")
  , ("patsy", "493-2928")
  , ("lucille", "205-2928")
  , ("wendy", "939-8282")
  , ("penny", "853-2492")
  ]

inPhoneBook :: Name -> PhoneNumber -> PhoneBook -> Bool
inPhoneBook name pnumber pbook = (name, pnumber) `elem` pbook

type AssocList :: Type -> Type -> Type
type AssocList k v = [(k, v)]

-- |
-- Locker
type LockerState :: Type
data LockerState = Taken | Free
  deriving (Eq, Show)

type LockerID :: Type
type LockerID = Int

type LockerPasscode :: Type
type LockerPasscode = String

type LockerMessage :: Type
type LockerMessage = String

type LockerMap :: Type
type LockerMap = Map.Map LockerID (LockerState, LockerPasscode)

lockerLookup :: LockerID -> LockerMap -> Either LockerMessage LockerPasscode
lockerLookup lockerId lockerMap =
  case Map.lookup lockerId lockerMap of
    Nothing -> Left $ "Locker number " ++ show lockerId ++ " doesn't exist!"
    Just (state, passcode) ->
      if state /= Taken
        then Right passcode
        else Left $ "Locker " ++ show lockerId ++ " is already taken!"

lockers :: LockerMap
lockers =
  Map.fromList
    [ (100, (Taken, "ZD39I"))
    , (101, (Free, "JAH3I"))
    , (102, (Free, "IQSA9"))
    , (103, (Free, "QOTSA"))
    , (104, (Taken, "893JJ"))
    , (105, (Taken, "88292"))
    ]

-- List Data Constructor
-- data List a = Empty | Cons a (List a) deriving (Show, Read, Eq, Ord)
-- data List a = Empty | Cons { listHead :: a, listTail :: List a}
--   deriving (Show, Read, Eq, Ord)

infixr 5 :-:
type List :: Type -> Type
data List a = Empty
            | a :-: (List a)
  deriving (Eq, Ord, Read, Show)

-- |
-- fixity
infixr 5 .++

(.++) :: List a -> List a -> List a
Empty .++ ys      = ys
(x :-: xs) .++ ys = x :-: (xs .++ ys)

-- |
-- Tree
type Tree :: Type -> Type
data Tree a = Nil
            | Node a (Tree a) (Tree a)
  deriving (Eq, Read, Show)

singleton :: a -> Tree a
singleton x = Node x Nil Nil

treeInsert :: (Ord a) => a -> Tree a -> Tree a
treeInsert x Nil = singleton x
treeInsert x (Node a left right)
  | x == a = Node x left right
  | x < a = Node a (treeInsert x left) right
  | x > a = Node a left (treeInsert x right)

infixr 5 *>>
(*>>) :: (Ord a) => a -> Tree a -> Tree a
x *>> Nil = singleton x
x *>> (Node a left right)
  | x == a = Node x left right
  | x < a = Node a (x *>> left) right
  | x > a = Node a left (x *>> right)

treeElem :: (Ord a) => a -> Tree a -> Bool
treeElem x Nil = False
treeElem x (Node a left right)
  | x == a = True
  | x < a = treeElem x left
  | x > a = treeElem x right

infixr 5 *??
(*??) :: (Ord a) => a -> Tree a -> Bool
x *?? Nil = False
x *?? (Node a left right)
  | x == a = True
  | x < a = x *?? left
  | x > a = x *?? right

-- |
-- TrafficLight
type TrafficLight :: Type
data TrafficLight = Red | Yellow | Green

instance Eq TrafficLight where
  Red == Red       = True
  Green == Green   = True
  Yellow == Yellow = True
  _ == _           = False

instance Show TrafficLight where
  show Red    = "Red light"
  show Yellow = "Yellow light"
  show Green  = "Green light"

-- |
-- Type class declaration and Instantiation of Type class
type YesNo :: Type -> Constraint
class YesNo a where -- `a` is a type variable for concrete type
  yesno :: a -> Bool

instance YesNo Int where
  yesno 0 = False
  yesno _ = True

instance YesNo [a] where
  yesno [] = False
  yesno _  = True

instance YesNo Bool where
  yesno = id

instance YesNo (Maybe a) where
  yesno (Just _) = True
  yesno Nothing  = False

yesnoIf :: (YesNo y) => y -> a -> a -> a
yesnoIf yesnoVal yesResult noResult =
  if yesno yesnoVal
    then yesResult
    else noResult

-- Instantiations of Functor type class
-- `f` is a type constructor having only one type variable
--
-- class Functor f where
--    fmap :: (a -> b) -> f a -> f b
--    ...

instance Functor Tree where -- `Tree` is a type constructor having only one type variable
  fmap f Nil = Nil
  fmap f (Node x leftsub rightsub) =
    Node (f x) (fmap f leftsub) (fmap f rightsub)

-- |
-- `j a` :: Type
--  `a` :: Type
-- `j'   :: Type -> Type
-- `t a j` :: Type
-- *`a` -> (* -> *)`j` -> *`t`
type Tofu :: (* -> (* -> *) -> *) -> Constraint
class Tofu t where
  tofu :: j a -> t a j

type Frank :: Type -> (* -> *) -> *
data Frank a b = Frank
  { frankField :: b a
  }
  deriving (Show)

instance Tofu Frank where
  tofu x = Frank x

type Barry :: (* -> *) -> * -> * -> *
data Barry t k p = Barry
  { yabba :: p
  , dabba :: t k
  }

instance Functor (Barry a b) where
  fmap f (Barry {yabba = x, dabba = y}) = Barry {yabba = f x, dabba = y}
