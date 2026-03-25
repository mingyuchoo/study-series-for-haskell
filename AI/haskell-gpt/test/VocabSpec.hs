module VocabSpec
    ( spec
    ) where

import qualified Data.Set         as Set

import           HaskellGPT.Vocab

import           Test.Hspec

spec :: Spec
spec = do
  describe "Vocabulary Management" $ do
    describe "newVocab" $ do
      it "creates vocabulary from word list" $ do
        let wordList = ["hello", "world", "test"]
        let vocab = newVocab wordList
        vocabSize vocab `shouldBe` 3
        vocabWords vocab `shouldBe` wordList

      it "assigns sequential token IDs" $ do
        let vocab = newVocab ["first", "second", "third"]
        encode vocab "first" `shouldBe` Just 0
        encode vocab "second" `shouldBe` Just 1
        encode vocab "third" `shouldBe` Just 2

      it "handles empty word list" $ do
        let vocab = newVocab []
        vocabSize vocab `shouldBe` 0
        encode vocab "anything" `shouldBe` Nothing

    describe "encode" $ do
      it "encodes words to token IDs correctly" $ do
        let vocab = newVocab ["apple", "banana", "cherry"]
        encode vocab "apple" `shouldBe` Just 0
        encode vocab "banana" `shouldBe` Just 1
        encode vocab "cherry" `shouldBe` Just 2

      it "returns Nothing for unknown words" $ do
        let vocab = newVocab ["known", "words"]
        encode vocab "unknown" `shouldBe` Nothing
        encode vocab "" `shouldBe` Nothing

      it "is case-sensitive" $ do
        let vocab = newVocab ["Hello", "hello"]
        encode vocab "Hello" `shouldBe` Just 0
        encode vocab "hello" `shouldBe` Just 1
        encode vocab "HELLO" `shouldBe` Nothing

    describe "decode" $ do
      it "decodes token IDs to words correctly" $ do
        let vocab = newVocab ["dog", "cat", "bird"]
        decode vocab 0 `shouldBe` Just "dog"
        decode vocab 1 `shouldBe` Just "cat"
        decode vocab 2 `shouldBe` Just "bird"

      it "returns Nothing for invalid token IDs" $ do
        let vocab = newVocab ["word1", "word2"]
        decode vocab 5 `shouldBe` Nothing
        decode vocab (-1) `shouldBe` Nothing
        decode vocab 100 `shouldBe` Nothing

    describe "bidirectional mapping consistency" $ do
      it "encode and decode are inverse operations" $ do
        let vocab = newVocab ["alpha", "beta", "gamma", "delta"]
        -- Encode then decode should return original word
        let word = "beta"
        case encode vocab word of
          Just tokenId -> decode vocab tokenId `shouldBe` Just word
          Nothing      -> expectationFailure "Word should be in vocabulary"

      it "decode and encode are inverse operations" $ do
        let vocab = newVocab ["one", "two", "three"]
        -- Decode then encode should return original token ID
        let tokenId = 1
        case decode vocab tokenId of
          Just word -> encode vocab word `shouldBe` Just tokenId
          Nothing   -> expectationFailure "Token ID should be in vocabulary"

      it "maintains consistency for all words in vocabulary" $ do
        let wordList = ["red", "green", "blue", "yellow"]
        let vocab = newVocab wordList
        -- For each word, encode then decode should return the same word
        let roundTrip word = case encode vocab word of
              Just tid -> decode vocab tid
              Nothing  -> Nothing
        map roundTrip wordList `shouldBe` map Just wordList

    describe "defaultVocab" $ do
      it "contains special tokens" $ do
        encode defaultVocab "[PAD]" `shouldSatisfy` (/= Nothing)
        encode defaultVocab "[UNK]" `shouldSatisfy` (/= Nothing)
        encode defaultVocab "[START]" `shouldSatisfy` (/= Nothing)
        encode defaultVocab "[END]" `shouldSatisfy` (/= Nothing)
        encode defaultVocab "</s>" `shouldSatisfy` (/= Nothing)

      it "special tokens have expected IDs" $ do
        encode defaultVocab "[PAD]" `shouldBe` Just 0
        encode defaultVocab "[UNK]" `shouldBe` Just 1
        encode defaultVocab "[START]" `shouldBe` Just 2
        encode defaultVocab "[END]" `shouldBe` Just 3
        encode defaultVocab "</s>" `shouldBe` Just 4

      it "contains common words" $ do
        encode defaultVocab "the" `shouldSatisfy` (/= Nothing)
        encode defaultVocab "and" `shouldSatisfy` (/= Nothing)
        encode defaultVocab "hello" `shouldSatisfy` (/= Nothing)

      it "contains punctuation" $ do
        encode defaultVocab "." `shouldSatisfy` (/= Nothing)
        encode defaultVocab "," `shouldSatisfy` (/= Nothing)
        encode defaultVocab "!" `shouldSatisfy` (/= Nothing)
        encode defaultVocab "?" `shouldSatisfy` (/= Nothing)

      it "has non-zero size" $ do
        vocabSize defaultVocab `shouldSatisfy` (> 0)

    describe "processTextForVocab" $ do
      it "extracts unique words from text" $ do
        let texts = ["hello world", "hello there"]
        let uniqueWords = processTextForVocab texts
        Set.member "hello" uniqueWords `shouldBe` True
        Set.member "world" uniqueWords `shouldBe` True
        Set.member "there" uniqueWords `shouldBe` True
        Set.size uniqueWords `shouldBe` 3

      it "handles punctuation as separate tokens" $ do
        let texts = ["Hello, world!"]
        let uniqueWords = processTextForVocab texts
        Set.member "Hello" uniqueWords `shouldBe` True
        Set.member "," uniqueWords `shouldBe` True
        Set.member "world" uniqueWords `shouldBe` True
        Set.member "!" uniqueWords `shouldBe` True

      it "preserves case sensitivity" $ do
        let texts = ["Hello hello HELLO"]
        let uniqueWords = processTextForVocab texts
        Set.member "Hello" uniqueWords `shouldBe` True
        Set.member "hello" uniqueWords `shouldBe` True
        Set.member "HELLO" uniqueWords `shouldBe` True
        Set.size uniqueWords `shouldBe` 3

      it "handles empty input" $ do
        let uniqueWords = processTextForVocab []
        Set.size uniqueWords `shouldBe` 0

      it "handles empty strings" $ do
        let uniqueWords = processTextForVocab ["", "  ", ""]
        Set.size uniqueWords `shouldBe` 0

      it "splits contractions correctly" $ do
        let texts = ["it's don't can't"]
        let uniqueWords = processTextForVocab texts
        Set.member "it" uniqueWords `shouldBe` True
        Set.member "'" uniqueWords `shouldBe` True
        Set.member "s" uniqueWords `shouldBe` True
        Set.member "don" uniqueWords `shouldBe` True
        Set.member "t" uniqueWords `shouldBe` True

      it "handles multiple punctuation marks" $ do
        let texts = ["Hello... world!!!"]
        let uniqueWords = processTextForVocab texts
        Set.member "Hello" uniqueWords `shouldBe` True
        Set.member "..." uniqueWords `shouldBe` True
        Set.member "world" uniqueWords `shouldBe` True
        Set.member "!!!" uniqueWords `shouldBe` True

    describe "unknown word handling" $ do
      it "returns Nothing for words not in vocabulary" $ do
        let vocab = newVocab ["known"]
        encode vocab "unknown" `shouldBe` Nothing

      it "can use [UNK] token for unknown words" $ do
        -- This tests that the default vocab has an unknown token
        encode defaultVocab "[UNK]" `shouldSatisfy` (/= Nothing)

      it "handles special characters not in vocabulary" $ do
        let vocab = newVocab ["word"]
        encode vocab "§" `shouldBe` Nothing
        encode vocab "€" `shouldBe` Nothing

    describe "vocabSize" $ do
      it "returns correct vocabulary size" $ do
        let vocab = newVocab ["a", "b", "c", "d", "e"]
        vocabSize vocab `shouldBe` 5

      it "returns 0 for empty vocabulary" $ do
        let vocab = newVocab []
        vocabSize vocab `shouldBe` 0

      it "matches length of vocabWords" $ do
        let wordList = ["one", "two", "three", "four"]
        let vocab = newVocab wordList
        vocabSize vocab `shouldBe` length (vocabWords vocab)

