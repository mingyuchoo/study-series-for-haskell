module Fzh.Application.Workflow
    ( InputSource (..)
    , Outcome (..)
    , Workflow (..)
    , WorkflowCommand (..)
    , WorkflowEvent (..)
    , transitionWorkflow
    , workflowFinished
    ) where

import           Fzh.Domain.Config
import qualified Fzh.Domain.Search  as Search
import           Fzh.Domain.Session

data InputSource = StandardInput
                 | FileSystem FilePath
     deriving (Eq, Show)

data Outcome = NoInput
             | Selection (Maybe String)
     deriving (Eq, Show)

data Workflow = Ready
              | DetectingSource
              | GatheringInput InputSource
              | ReadingConfig [String]
              | RunningSession [String] KeyBindingConfig
              | WritingOutput Outcome
              | WorkflowCompleted Outcome
              | WorkflowFailed String
     deriving (Eq, Show)

data WorkflowEvent = Start
                   | SourceDetected InputSource
                   | InputGathered [String]
                   | ConfigurationRead ConfigResult
                   | SessionEnded Session
                   | OutputWritten
                   | WarningReported
                   | OperationFailed String
     deriving (Eq, Show)

data WorkflowCommand = DetectSource
                     | GatherInput InputSource
                     | ReadConfig
                     | LaunchSession [String] KeyBindingConfig
                     | WriteOutput Outcome
                     | ReportWarning String
     deriving (Eq, Show)

transitionWorkflow :: WorkflowEvent -> Workflow -> (Workflow, [WorkflowCommand])
transitionWorkflow event workflow
  | workflowFinished workflow = (workflow, [])
  | otherwise = case (event, workflow) of
      (OperationFailed problem, _) -> (WorkflowFailed problem, [])
      (Start, Ready) -> (DetectingSource, [DetectSource])
      (SourceDetected source, DetectingSource) -> (GatheringInput source, [GatherInput source])
      (InputGathered [], GatheringInput _) -> (WritingOutput NoInput, [WriteOutput NoInput])
      (InputGathered items, GatheringInput _) -> (ReadingConfig items, [ReadConfig])
      (ConfigurationRead result, ReadingConfig items) ->
        let config = resolvedConfig result
            warnings = case result of
              ConfigInvalid problem -> [ReportWarning problem]
              _                     -> []
         in (RunningSession items config, warnings ++ [LaunchSession items config])
      (SessionEnded (Finished _ browser), RunningSession _ _) ->
        let outcome = Selection (Search.selectedItem (browserSearch browser))
         in (WritingOutput outcome, [WriteOutput outcome])
      (SessionEnded (Browsing _), RunningSession _ _) -> (WorkflowFailed "Session returned before finishing", [])
      (OutputWritten, WritingOutput outcome) -> (WorkflowCompleted outcome, [])
      _ -> (workflow, [])

workflowFinished :: Workflow -> Bool
workflowFinished (WorkflowCompleted _) = True
workflowFinished (WorkflowFailed _)    = True
workflowFinished _                     = False
