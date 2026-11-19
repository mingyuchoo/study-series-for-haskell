module Main
    ( main
    ) where

import           Control.Monad.State.Strict (State, modify, runState, state)

import           Fzh.Application.Ports
import           Fzh.Application.Workflow
import           Fzh.Domain.Config
import           Fzh.Domain.Session

import           Test.Hspec

main :: IO ()
main = hspec $ do
  describe "workflow" $ do
    it "starts by detecting the input source" $ do
      transitionWorkflow Start Ready `shouldBe` (DetectingSource, [DetectSource])
    it "collects each detected input source explicitly" $ do
      mapM_
        ( \source ->
            transitionWorkflow (SourceDetected source) DetectingSource
              `shouldBe` (GatheringInput source, [GatherInput source])
        )
        [StandardInput, FileSystem "."]
    it "writes the empty-input outcome without loading configuration or starting a terminal" $ do
      transitionWorkflow (InputGathered []) (GatheringInput StandardInput)
        `shouldBe` (WritingOutput NoInput, [WriteOutput NoInput])
    it "loads configuration after collecting items" $ do
      transitionWorkflow (InputGathered ["a"]) (GatheringInput StandardInput)
        `shouldBe` (ReadingConfig ["a"], [ReadConfig])
    it "uses configured bindings or defaults and reports invalid configuration" $ do
      transitionWorkflow
        (ConfigurationRead (ConfigLoaded (KeyBindingConfig Vim)))
        (ReadingConfig ["a"])
        `shouldBe` ( RunningSession ["a"] (KeyBindingConfig Vim)
                   , [LaunchSession ["a"] (KeyBindingConfig Vim)]
                   )
      transitionWorkflow (ConfigurationRead ConfigMissing) (ReadingConfig ["a"])
        `shouldBe` ( RunningSession ["a"] defaultKeyBindingConfig
                   , [LaunchSession ["a"] defaultKeyBindingConfig]
                   )
      transitionWorkflow (ConfigurationRead (ConfigInvalid "bad yaml")) (ReadingConfig ["a"])
        `shouldBe` ( RunningSession ["a"] defaultKeyBindingConfig
                   , [ReportWarning "bad yaml", LaunchSession ["a"] defaultKeyBindingConfig]
                   )
    it "preserves current-selection output for both exit reasons" $ do
      let initial = newSession ["a"] (80, 24)
      mapM_
        ( \event -> do
            let (finished, _) = transitionSession event initial
            transitionWorkflow (SessionEnded finished) (RunningSession ["a"] defaultKeyBindingConfig)
              `shouldBe` (WritingOutput (Selection (Just "a")), [WriteOutput (Selection (Just "a"))])
        )
        [Confirm, Dismiss]
    it "handles a finished session with no selection" $ do
      let (finished, _) = transitionSession Confirm (newSession [] (80, 24))
      transitionWorkflow (SessionEnded finished) (RunningSession [] defaultKeyBindingConfig)
        `shouldBe` (WritingOutput (Selection Nothing), [WriteOutput (Selection Nothing)])
    it "only completes after output succeeds" $ do
      transitionWorkflow OutputWritten (WritingOutput NoInput)
        `shouldBe` (WorkflowCompleted NoInput, [])
      transitionWorkflow (OperationFailed "broken pipe") (WritingOutput NoInput)
        `shouldBe` (WorkflowFailed "broken pipe", [])
    it "ignores out-of-order events and all events after termination" $ do
      transitionWorkflow (InputGathered ["a"]) Ready `shouldBe` (Ready, [])
      mapM_
        ( \terminal ->
            mapM_
              (\event -> transitionWorkflow event terminal `shouldBe` (terminal, []))
              [Start, SourceDetected StandardInput, InputGathered [], OperationFailed "late"]
        )
        [WorkflowCompleted NoInput, WorkflowFailed "failed"]
  describe "workflow ports" $ do
    it "runs the complete pipeline through injected ports in order" $ do
      let (finished, _) = transitionSession Confirm (newSession ["a"] (80, 24))
          ports =
            WorkflowPorts
              { detectSource = record "detect" (Right StandardInput)
              , gatherInput = \source -> record (show source) (Right ["a"])
              , readConfiguration = record "config" (ConfigInvalid "invalid")
              , launchSession = \items config -> record (show (items, config)) (Right finished)
              , writeOutput = \outcome -> record (show outcome) (Right ())
              , reportWarning = \problem -> record problem ()
              }
          (result, calls) = runState (runWorkflow ports) []
      result `shouldBe` WorkflowCompleted (Selection (Just "a"))
      calls
        `shouldBe` [ "detect"
                   , "StandardInput"
                   , "config"
                   , "invalid"
                   , "([\"a\"],KeyBindingConfig {bindingStyle = Emacs})"
                   , "Selection (Just \"a\")"
                   ]
    it "stops after a failed input port without invoking later ports" $ do
      let ports =
            WorkflowPorts
              { detectSource = pure (Right StandardInput)
              , gatherInput = \_ -> pure (Left "input failed")
              , readConfiguration = unexpected
              , launchSession = \_ _ -> unexpected
              , writeOutput = \_ -> unexpected
              , reportWarning = \_ -> unexpected
              }
          (result, called) = runState (runWorkflow ports) False
      result `shouldBe` WorkflowFailed "input failed"
      called `shouldBe` False

record :: String -> a -> State [String] a
record name value = state (\calls -> (value, calls ++ [name]))

unexpected :: State Bool a
unexpected = modify (const True) >> error "unexpected port invocation"
