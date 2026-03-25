module Main
  ( main,
  )
where

import Control.Monad (when)
import Data.Set qualified as Set
import HaskellGPT
import System.IO (BufferMode (NoBuffering), hFlush, hSetBuffering, stdout)

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  putStrLn "HaskellGPT - Transformer-based Language Model"
  putStrLn "=============================================="
  putStrLn ""

  -- 1. Load pretraining and chat training data from JSON files
  putStrLn "Loading training data..."
  datasetResult <- loadDataset "data/pretraining_data.json" "data/chat_training_data.json" JSON

  case datasetResult of
    Left err -> do
      putStrLn $ "Error loading dataset: " ++ err
      putStrLn "Please ensure data files exist in the data/ directory"
      return ()
    Right dataset -> do
      let pretrainData = datasetPretraining dataset
      let chatData = datasetChatTraining dataset

      putStrLn $ "Loaded " ++ show (length pretrainData) ++ " pretraining examples"
      putStrLn $ "Loaded " ++ show (length chatData) ++ " chat training examples"
      putStrLn ""

      -- 2. Build vocabulary from all training data
      putStrLn "Building vocabulary..."
      let allTexts = pretrainData ++ chatData
      let uniqueWords = processTextForVocab allTexts
      let wordList = Set.toList uniqueWords

      -- Add special tokens to vocabulary
      let specialTokens = ["[PAD]", "[UNK]", "[START]", "[END]", "</s>"]
      let fullVocab = specialTokens ++ wordList
      let vocab = newVocab fullVocab

      putStrLn $ "Vocabulary size: " ++ show (vocabSize vocab)
      putStrLn ""

      -- 3. Create LLM with embeddings, 3 transformer blocks, and output projection
      putStrLn "Initializing model..."
      llm <- createLLM vocab

      -- 4. Display model information
      putStrLn ""
      putStrLn "Model Configuration:"
      putStrLn $ "  Embedding Dimension: " ++ show embeddingDim
      putStrLn $ "  Hidden Dimension: " ++ show hiddenDim
      putStrLn $ "  Max Sequence Length: " ++ show maxSeqLen
      putStrLn $ "  Number of Transformer Blocks: 3"
      putStrLn $ "  Vocabulary Size: " ++ show (vocabSize vocab)
      putStrLn ""
      putStrLn (networkDescription llm)
      putStrLn ""
      putStrLn $ "Total Parameters: " ++ show (totalParameters llm)
      putStrLn ""

      -- Display before training prediction
      putStrLn "Before Training Prediction:"
      let testPrompt = "User: Hello"
      let beforePrediction = predict llm testPrompt
      putStrLn $ "  Input: " ++ testPrompt
      putStrLn $ "  Output: " ++ beforePrediction
      putStrLn ""

      -- 5. Perform pretraining for 100 epochs with learning rate 0.0005
      putStrLn "Starting Pretraining..."
      putStrLn "======================="
      llmAfterPretrain <- train llm pretrainData 100 0.0005
      putStrLn ""

      -- 6. Perform instruction tuning for 100 epochs with learning rate 0.0001
      putStrLn "Starting Instruction Tuning..."
      putStrLn "=============================="
      llmAfterTuning <- train llmAfterPretrain chatData 100 0.0001
      putStrLn ""

      -- Display after training prediction
      putStrLn "After Training Prediction:"
      let afterPrediction = predict llmAfterTuning testPrompt
      putStrLn $ "  Input: " ++ testPrompt
      putStrLn $ "  Output: " ++ afterPrediction
      putStrLn ""

      -- 7. Enter interactive mode
      putStrLn "Entering Interactive Mode..."
      putStrLn "============================"
      putStrLn "Type your prompts below. Type 'exit' to quit."
      putStrLn ""
      interactiveLoop llmAfterTuning

-- | Create LLM with embeddings, 3 transformer blocks, and output projection
createLLM :: Vocab -> IO LLM
createLLM vocab = do
  -- Create embeddings layer
  embeddings <- newEmbeddings vocab

  -- Create 3 transformer blocks
  transformer1 <- newTransformerBlock embeddingDim hiddenDim
  transformer2 <- newTransformerBlock embeddingDim hiddenDim
  transformer3 <- newTransformerBlock embeddingDim hiddenDim

  -- Create output projection layer
  outputProj <- newOutputProjection embeddingDim (vocabSize vocab)

  -- Wrap layers in SomeLayer existential type
  let network =
        [ SomeLayer embeddings,
          SomeLayer transformer1,
          SomeLayer transformer2,
          SomeLayer transformer3,
          SomeLayer outputProj
        ]

  return $ newLLM vocab network

-- | Interactive loop for user prompts
-- Reads user input, generates response, and displays output
-- Exits when user types "exit"
interactiveLoop :: LLM -> IO ()
interactiveLoop llm = do
  putStr "User: "
  hFlush stdout
  userInput <- getLine

  -- Check for exit command
  when (userInput /= "exit") $ do
    -- Generate response
    let response = predict llm userInput
    putStrLn $ "Assistant: " ++ response
    putStrLn ""

    -- Continue loop
    interactiveLoop llm
