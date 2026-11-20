module GitPuller.Application.Interaction.Survey (
  survey,
)
where

import Control.Monad (replicateM_)
import Data.Foldable (toList)
import GitPuller.Application.Event (Event (..))
import GitPuller.Application.Program (Program, Request (..), await, concurrently, report)
import GitPuller.Domain.Discovery (Candidate, Discovery (..), Listing (..))
import GitPuller.Domain.Discovery qualified as Discovery

survey :: FilePath -> Program [Candidate]
survey root = do
  report Scanning
  explore (Discovery.start root)

list :: FilePath -> Program Listing
list location = Listing location <$> await (ListDirectory location)

explore :: Discovery -> Program [Candidate]
explore discovery = case discovery of
  Complete candidates -> pure candidates
  Exploring directories _ -> do
    listings <- concurrently (map list (toList directories))
    let (next, discovered) = Discovery.afterListings discovery listings
    replicateM_ discovered (report Discovered)
    explore next
