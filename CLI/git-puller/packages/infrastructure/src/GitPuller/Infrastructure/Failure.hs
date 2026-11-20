module GitPuller.Infrastructure.Failure (
  reason,
  reasonWithLocation,
)
where

import Control.Exception (displayException)
import GHC.IO.Exception (IOException (..))

reason :: IOException -> String
reason failure
  | null (ioe_description failure) = displayException failure
  | otherwise = ioe_description failure

reasonWithLocation :: IOException -> String
reasonWithLocation failure =
  maybe (reason failure) (\location -> location <> ": " <> reason failure) (ioe_filename failure)
