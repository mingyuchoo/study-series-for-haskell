module GitPuller.Application.Interaction.Update
  ( update
  ) where

import GitPuller.Application.Event (Event (..))
import GitPuller.Application.Program (Program, Request (..), await, exclusively, report)
import GitPuller.Domain.Discovery (Candidate)
import GitPuller.Domain.Discovery qualified as Discovery
import GitPuller.Domain.Outcome (Outcome (..), Status)
import GitPuller.Domain.Update (Mode, Phase (..), Signal (..))
import GitPuller.Domain.Update qualified as Update

settle :: FilePath -> Status -> Program Outcome
settle location result = do
  let outcome = Outcome {path = location, status = result}
  report (Processed outcome)
  pure outcome

inspect :: FilePath -> Program Signal
inspect location = do
  report (Inspecting location)
  Inspected <$> await (InspectRepository location)

pull :: FilePath -> FilePath -> Program Signal
pull commonDirectory location = exclusively commonDirectory $ do
  report (Pulling location)
  Pulled <$> await (Pull location)

update :: Mode -> Candidate -> Program Outcome
update mode candidate = conclude (Update.begin candidate)
  where
    location = Discovery.location candidate
    conclude phase = case phase of
      AwaitingInspection           -> inspect location >>= advance phase
      AwaitingPull commonDirectory -> pull commonDirectory location >>= advance phase
      Settled result               -> settle location result
    advance phase = conclude . Update.transition mode phase
