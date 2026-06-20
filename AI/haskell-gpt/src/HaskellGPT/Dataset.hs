module HaskellGPT.Dataset
  ( Dataset (..)
  , DatasetType (..)
  , loadDataset
  , loadFromCSV
  , loadFromJSON
  ) where

import Control.Exception (IOException, try)

import Data.Aeson qualified as Aeson
import Data.ByteString.Lazy qualified as BL
import Data.Csv qualified as Csv
import Data.Text qualified as T
import Data.Text.Encoding qualified as TE
import Data.Vector qualified as V

-- | Type of dataset to load
data DatasetType = JSON | CSV
  deriving (Eq, Show)

-- | Dataset containing pretraining and chat training data
data Dataset = Dataset
  { datasetPretraining  :: [String]
  , datasetChatTraining :: [String]
  }
  deriving (Eq, Show)

-- | Load dataset from files based on DatasetType
-- Returns Either error message or Dataset
loadDataset :: FilePath -> FilePath -> DatasetType -> IO (Either String Dataset)
loadDataset pretrainPath chatPath datasetType = do
  case datasetType of
    JSON -> do
      pretrainResult <- loadFromJSON pretrainPath
      chatResult <- loadFromJSON chatPath
      case (pretrainResult, chatResult) of
        (Right pretrain, Right chat) ->
          return $ Right $ Dataset pretrain chat
        (Left err, _) ->
          return $ Left $ "Failed to load pretraining data: " ++ err
        (_, Left err) ->
          return $ Left $ "Failed to load chat training data: " ++ err
    CSV -> do
      pretrainResult <- loadFromCSV pretrainPath
      chatResult <- loadFromCSV chatPath
      case (pretrainResult, chatResult) of
        (Right pretrain, Right chat) ->
          return $ Right $ Dataset pretrain chat
        (Left err, _) ->
          return $ Left $ "Failed to load pretraining data: " ++ err
        (_, Left err) ->
          return $ Left $ "Failed to load chat training data: " ++ err

-- | Load data from JSON file
-- Expects a JSON array of strings
loadFromJSON :: FilePath -> IO (Either String [String])
loadFromJSON filePath = do
  result <- try (BL.readFile filePath) :: IO (Either IOException BL.ByteString)
  case result of
    Left err ->
      return $ Left $ "IO error reading file: " ++ show err
    Right contents ->
      case Aeson.eitherDecode contents of
        Left err ->
          return $ Left $ "JSON parse error: " ++ err
        Right texts ->
          return $ Right texts

-- | Load data from CSV file
-- Expects a CSV file with one column containing text data
loadFromCSV :: FilePath -> IO (Either String [String])
loadFromCSV filePath = do
  result <- try (BL.readFile filePath) :: IO (Either IOException BL.ByteString)
  case result of
    Left err ->
      return $ Left $ "IO error reading file: " ++ show err
    Right contents ->
      case Csv.decode Csv.NoHeader contents of
        Left err ->
          return $ Left $ "CSV parse error: " ++ err
        Right rows -> do
          -- Extract first column from each row
          let texts = V.toList $ V.map extractFirstColumn rows
          return $ Right texts
  where
    -- Extract first column from a CSV row (assuming single column)
    extractFirstColumn :: V.Vector BL.ByteString -> String
    extractFirstColumn row =
      if V.null row
        then ""
        else T.unpack $ TE.decodeUtf8 $ BL.toStrict $ V.head row
