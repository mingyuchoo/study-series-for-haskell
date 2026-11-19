module Fzh.Application.Ports
    ( WorkflowPorts (..)
    , runWorkflow
    ) where

import           Fzh.Application.Workflow
import           Fzh.Domain.Config        (ConfigResult, KeyBindingConfig)
import           Fzh.Domain.Session       (Session)

data WorkflowPorts m = WorkflowPorts { detectSource :: m (Either String InputSource)
                                     , gatherInput :: InputSource -> m (Either String [String])
                                     , readConfiguration :: m ConfigResult
                                     , launchSession :: [String] -> KeyBindingConfig -> m (Either String Session)
                                     , writeOutput :: Outcome -> m (Either String ())
                                     , reportWarning :: String -> m ()
                                     }

runWorkflow :: (Monad m) => WorkflowPorts m -> m Workflow
runWorkflow ports = uncurry run (transitionWorkflow Start Ready)
  where
    run workflow [] = pure workflow
    run workflow (command : pending)
      | workflowFinished workflow = pure workflow
      | otherwise = do
          event <- execute command
          let (next, commands) = transitionWorkflow event workflow
          run next (commands ++ pending)
    execute command = case command of
      DetectSource -> either OperationFailed SourceDetected <$> detectSource ports
      GatherInput source -> either OperationFailed InputGathered <$> gatherInput ports source
      ReadConfig -> ConfigurationRead <$> readConfiguration ports
      LaunchSession items config -> either OperationFailed SessionEnded <$> launchSession ports items config
      WriteOutput outcome -> either OperationFailed (const OutputWritten) <$> writeOutput ports outcome
      ReportWarning problem -> reportWarning ports problem >> pure WarningReported
