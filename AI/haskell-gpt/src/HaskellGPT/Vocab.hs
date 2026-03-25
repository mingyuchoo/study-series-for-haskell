{-# LANGUAGE BangPatterns #-}

module HaskellGPT.Vocab
    ( Vocab (..)
    , decode
    , defaultVocab
    , encode
    , newVocab
    , processTextForVocab
    , vocabSize
    ) where

import           Data.Char       (isAlphaNum, isPunctuation)

import qualified Data.Map.Strict as Map
import qualified Data.Set        as Set

-- | Vocabulary data structure with bidirectional mappings
-- Provides O(1) lookup for both word-to-ID and ID-to-word conversions
data Vocab = Vocab { vocabEncode :: !(Map.Map String Int)
                     -- ^ Word to token ID mapping
                   , vocabDecode :: !(Map.Map Int String)
                     -- ^ Token ID to word mapping
                   , vocabWords  :: ![String]
                     -- ^ List of all words in vocabulary
                   }
     deriving (Eq, Show)

-- | Create a new vocabulary from a list of words
-- Builds bidirectional mappings for efficient encoding and decoding
--
-- The words are assigned token IDs based on their position in the list (0-indexed)
--
-- >>> let vocab = newVocab ["hello", "world"]
-- >>> encode vocab "hello"
-- Just 0
-- >>> decode vocab 0
-- Just "hello"
newVocab :: [String] -> Vocab
newVocab wordList =
  let -- Create word to ID mapping
      encodeMap = Map.fromList $ zip wordList [0..]
      -- Create ID to word mapping
      decodeMap = Map.fromList $ zip [0..] wordList
  in Vocab
    { vocabEncode = encodeMap
    , vocabDecode = decodeMap
    , vocabWords = wordList
    }

-- | Encode a word to its token ID
-- Returns Nothing if the word is not in the vocabulary
--
-- >>> encode defaultVocab "[PAD]"
-- Just 0
-- >>> encode defaultVocab "unknown_word"
-- Nothing
encode :: Vocab -> String -> Maybe Int
encode vocab word = Map.lookup word (vocabEncode vocab)

-- | Decode a token ID to its corresponding word
-- Returns Nothing if the token ID is not in the vocabulary
--
-- >>> decode defaultVocab 0
-- Just "[PAD]"
-- >>> decode defaultVocab 999999
-- Nothing
decode :: Vocab -> Int -> Maybe String
decode vocab tokenId = Map.lookup tokenId (vocabDecode vocab)

-- | Get the size of the vocabulary
vocabSize :: Vocab -> Int
vocabSize vocab = length (vocabWords vocab)

-- | Default vocabulary with special tokens and common words
-- Includes special tokens: [PAD], [UNK], [START], [END], </s>
-- Plus a set of common English words for basic functionality
defaultVocab :: Vocab
defaultVocab = newVocab $
  -- Special tokens
  [ "[PAD]"
  , "[UNK]"
  , "[START]"
  , "[END]"
  , "</s>"
  ] ++
  -- Common words and punctuation
  [ "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for"
  , "of", "with", "by", "from", "as", "is", "was", "are", "were", "be"
  , "been", "being", "have", "has", "had", "do", "does", "did", "will"
  , "would", "should", "could", "can", "may", "might", "must", "shall"
  , "I", "you", "he", "she", "it", "we", "they", "me", "him", "her"
  , "us", "them", "my", "your", "his", "its", "our", "their", "this"
  , "that", "these", "those", "what", "which", "who", "whom", "whose"
  , "when", "where", "why", "how", "all", "each", "every", "both"
  , "few", "more", "most", "other", "some", "such", "no", "not", "only"
  , "own", "same", "so", "than", "too", "very", "just", "now", "then"
  , "here", "there", "up", "down", "out", "over", "under", "again"
  , "further", "once", "also", "well", "even", "back", "through", "still"
  , ".", ",", "!", "?", ":", ";", "-", "(", ")", "[", "]", "{", "}"
  , "'", "\"", "/", "\\", "@", "#", "$", "%", "^", "&", "*", "+", "="
  , "hello", "hi", "hey", "goodbye", "bye", "thanks", "thank", "please"
  , "yes", "no", "ok", "okay", "sure", "maybe", "help", "sorry"
  , "User", "Assistant", "user", "assistant"
  ]

-- | Process text data to extract unique words for vocabulary building
-- Tokenizes text by splitting on whitespace and punctuation
-- Returns a Set of unique words found in the training data
--
-- This function:
-- 1. Splits text into words
-- 2. Handles punctuation as separate tokens
-- 3. Preserves case sensitivity
-- 4. Returns unique words as a Set
--
-- >>> processTextForVocab ["Hello, world!", "Hello there"]
-- fromList ["Hello","there","world",",","!"]
processTextForVocab :: [String] -> Set.Set String
processTextForVocab texts =
  let -- Process all texts and collect words
      allWords = concatMap tokenizeText texts
  in Set.fromList allWords

-- | Tokenize a single text string into words and punctuation
-- Splits on whitespace and treats punctuation as separate tokens
tokenizeText :: String -> [String]
tokenizeText text = concatMap splitWord (words text)

-- | Split a word into alphanumeric parts and punctuation
-- "hello," -> ["hello", ","]
-- "it's" -> ["it", "'", "s"]
splitWord :: String -> [String]
splitWord [] = []
splitWord str =
  let (alphanum, rest) = span isAlphaNum str
      (punct, remaining) = span isPunctuation rest
      result = filter (not . null) [alphanum, punct]
  in result ++ splitWord remaining

