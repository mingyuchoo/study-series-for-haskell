module DatasetSpec
    ( spec
    ) where

import qualified Data.Aeson           as Aeson
import qualified Data.ByteString.Lazy as BL

import           HaskellGPT.Dataset

import           System.FilePath      ((</>))
import           System.IO.Temp       (withSystemTempDirectory)

import           Test.Hspec

spec :: Spec
spec = do
  describe "Dataset Loader" $ do
    describe "loadFromJSON" $ do
      it "loads valid JSON array of strings" $ do
        withSystemTempDirectory "dataset-test" $ \tmpDir -> do
          let testFile = tmpDir </> "test.json"
          let testData = ["line 1", "line 2", "line 3"]
          BL.writeFile testFile (Aeson.encode testData)

          result <- loadFromJSON testFile
          result `shouldBe` Right testData

      it "handles empty JSON array" $ do
        withSystemTempDirectory "dataset-test" $ \tmpDir -> do
          let testFile = tmpDir </> "empty.json"
          BL.writeFile testFile (Aeson.encode ([] :: [String]))

          result <- loadFromJSON testFile
          result `shouldBe` Right []

      it "returns error for missing file" $ do
        result <- loadFromJSON "/nonexistent/path/file.json"
        result `shouldSatisfy` isLeft

      it "returns error for invalid JSON" $ do
        withSystemTempDirectory "dataset-test" $ \tmpDir -> do
          let testFile = tmpDir </> "invalid.json"
          BL.writeFile testFile (BL.pack $ map (fromIntegral . fromEnum) "{ invalid json }")

          result <- loadFromJSON testFile
          result `shouldSatisfy` isLeft

      it "loads JSON with special characters" $ do
        withSystemTempDirectory "dataset-test" $ \tmpDir -> do
          let testFile = tmpDir </> "special.json"
          let testData = ["Hello, world!", "Test </s>", "Line with \"quotes\""]
          BL.writeFile testFile (Aeson.encode testData)

          result <- loadFromJSON testFile
          result `shouldBe` Right testData

    describe "loadFromCSV" $ do
      it "loads valid CSV file" $ do
        withSystemTempDirectory "dataset-test" $ \tmpDir -> do
          let testFile = tmpDir </> "test.csv"
          let csvContent = "line 1\nline 2\nline 3\n"
          BL.writeFile testFile (BL.pack $ map (fromIntegral . fromEnum) csvContent)

          result <- loadFromCSV testFile
          result `shouldSatisfy` isRight

      it "handles empty CSV file" $ do
        withSystemTempDirectory "dataset-test" $ \tmpDir -> do
          let testFile = tmpDir </> "empty.csv"
          BL.writeFile testFile BL.empty

          result <- loadFromCSV testFile
          result `shouldSatisfy` isRight

      it "returns error for missing file" $ do
        result <- loadFromCSV "/nonexistent/path/file.csv"
        result `shouldSatisfy` isLeft

    describe "loadDataset" $ do
      it "loads both pretraining and chat data from JSON" $ do
        withSystemTempDirectory "dataset-test" $ \tmpDir -> do
          let pretrainFile = tmpDir </> "pretrain.json"
          let chatFile = tmpDir </> "chat.json"
          let pretrainData = ["pretrain 1", "pretrain 2"]
          let chatData = ["chat 1", "chat 2", "chat 3"]

          BL.writeFile pretrainFile (Aeson.encode pretrainData)
          BL.writeFile chatFile (Aeson.encode chatData)

          result <- loadDataset pretrainFile chatFile JSON
          case result of
            Right dataset -> do
              datasetPretraining dataset `shouldBe` pretrainData
              datasetChatTraining dataset `shouldBe` chatData
            Left err -> expectationFailure $ "Failed to load dataset: " ++ err

      it "returns error when pretraining file is missing" $ do
        withSystemTempDirectory "dataset-test" $ \tmpDir -> do
          let chatFile = tmpDir </> "chat.json"
          BL.writeFile chatFile (Aeson.encode (["chat"] :: [String]))

          result <- loadDataset "/nonexistent/pretrain.json" chatFile JSON
          result `shouldSatisfy` isLeft

      it "returns error when chat file is missing" $ do
        withSystemTempDirectory "dataset-test" $ \tmpDir -> do
          let pretrainFile = tmpDir </> "pretrain.json"
          BL.writeFile pretrainFile (Aeson.encode (["pretrain"] :: [String]))

          result <- loadDataset pretrainFile "/nonexistent/chat.json" JSON
          result `shouldSatisfy` isLeft

      it "loads CSV files when CSV type is specified" $ do
        withSystemTempDirectory "dataset-test" $ \tmpDir -> do
          let pretrainFile = tmpDir </> "pretrain.csv"
          let chatFile = tmpDir </> "chat.csv"
          let pretrainContent = "pretrain line 1\npretrain line 2\n"
          let chatContent = "chat line 1\n"

          BL.writeFile pretrainFile (BL.pack $ map (fromIntegral . fromEnum) pretrainContent)
          BL.writeFile chatFile (BL.pack $ map (fromIntegral . fromEnum) chatContent)

          result <- loadDataset pretrainFile chatFile CSV
          result `shouldSatisfy` isRight

-- Helper function to check if Either is Left
isLeft :: Either a b -> Bool
isLeft (Left _) = True
isLeft _        = False

-- Helper function to check if Either is Right
isRight :: Either a b -> Bool
isRight (Right _) = True
isRight _         = False
