module Chapter07.Modules
  where

import Data.Char (chr, digitToInt, isDigit, ord)
import Data.List
  ( any
  , find
  , foldl'
  , group
  , isInfixOf
  , isPrefixOf
  , length
  , nub
  , sort
  , tails
  , words
  )
import Data.Map qualified as Map (Map, fromList, fromListWith, insert, lookup, map, size)

-- | 리스트가 가지고 있는 요소들 가운데
-- 유일한 요소가 얼마나 많이 있는지 알려주는 함수
numUniques :: (Eq a) => [a] -> Int
numUniques = length . nub

-- | 엄청난 양의 단어들을 포함한 문자열에서
-- 각 단어들이 그 문자열에 몇 번 나오는지 알려주는 함수
wordNums :: String -> [(String, Int)]
wordNums = map (\w -> (head w, length w)) . group . sort . words

-- | 첫 번째 리스트 전체가 두 번쩨 리스트에 있는지 알려주는 함수
isIn :: (Eq a) => [a] -> [a] -> Bool
isIn needle haystack = any (needle `isPrefixOf`) (tails haystack)

-- | 알파벳의 고정된 위치만큼 각 문자를 이동하여
-- 메시지를 인코딩하는 시저 암호(Caesar cipher)로 만들어 알려주는 함수
encode :: Int -> String -> String
encode offset = map (chr . (+ offset) . ord)

-- | 시저 암호(Caesar cipher)로 만들어진 암호문을
-- 다시 평문으로 만들어 알려주는 함수
decode :: Int -> String -> String
decode shift = encode (negate shift)

-- | 일련의 자연수 합이 40이 되는 최초의 숫자를 알려주는 함수
firstTo :: Int -> Maybe Int
firstTo n = find (\x -> digitSum x == n) [1 ..]
  where
    digitSum :: Int -> Int
    digitSum = sum . map digitToInt . show

-- | 전화번호부에서 이름으로 전화번호를 찾아주는 함수
findPhoneNumber :: (Eq k) => k -> [(k, v)] -> Maybe v
findPhoneNumber key =
  foldr (\(k, v) acc -> if key == k then Just v else acc) Nothing

phoneBook :: [(String, String)]
phoneBook =
  [ ("betty", "555-2938")
  , ("betty", "342-2492")
  , ("bonnie", "452-2928")
  , ("patsy", "493-2928")
  , ("patsy", "827-2928")
  , ("lucille", "205-2928")
  , ("wendy", "939-8282")
  , ("penny", "853-2492")
  , ("penny", "555-1122")
  , ("penny", "342-0234")
  ]

string2digits :: String -> [Int]
string2digits = map digitToInt . filter isDigit

phoneBook' :: Map.Map String String
phoneBook' = Map.fromList phoneBook

phoneBookToMap :: (Ord k) => [(k, String)] -> Map.Map k String
phoneBookToMap =
  Map.fromListWith add
  where
    add number1 number2 = number1 ++ ", " ++ number2

phoneBookToMap' :: (Ord k) => [(k, a)] -> Map.Map k [a]
phoneBookToMap' xs = Map.fromListWith (++) $ map (\(k, v) -> (k, [v])) xs

-- | 함수를 적용합니다.
someFunc :: IO ()
someFunc = do
  print $ numUniques [1, 2, 3, 4, 5]
  print $ wordNums "foo bar foo baz"
  print $ "art" `isIn` "party"
  print $ "art" `isInfixOf` "party"
  print $ decode 3 $ encode 3 "Hey, Mark"
  -- print $ foldl' (+) 0 (replicate 1000000000 1) -- CPU 과도 사용
  print $ firstTo 40
  print $ findPhoneNumber "penny" phoneBook
