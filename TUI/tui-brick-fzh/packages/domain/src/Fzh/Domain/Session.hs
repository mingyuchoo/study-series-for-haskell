module Fzh.Domain.Session
    ( Browser
    , ExitReason (..)
    , PreviewError (..)
    , PreviewRequest (..)
    , PreviewState (..)
    , QueryEdit (..)
    , Session (..)
    , SessionCommand (..)
    , SessionEvent (..)
    , browserPreview
    , browserSearch
    , browserSize
    , newSession
    , sessionBrowser
    , transitionSession
    ) where

import           Fzh.Domain.Search (Direction, Search)
import qualified Fzh.Domain.Search as Search

data Session = Browsing Browser
             | Finished ExitReason Browser
     deriving (Eq, Show)

data Browser = Browser { browserSearch  :: Search
                       , browserSize    :: (Int, Int)
                       , browserPreview :: PreviewState
                       , nextRequest    :: Integer
                       }
     deriving (Eq, Show)

data PreviewRequest = PreviewRequest Integer FilePath
     deriving (Eq, Show)

data PreviewError = MissingFile
                  | PermissionDenied
                  | ReadError String
     deriving (Eq, Show)

data PreviewState = NoPreview
                  | Loading PreviewRequest
                  | Loaded FilePath String
                  | Failed FilePath PreviewError
     deriving (Eq, Show)

data ExitReason = Confirmed | Dismissed
     deriving (Eq, Show)

data QueryEdit = Append Char
               | Delete
               | Clear
     deriving (Eq, Show)

data SessionEvent = RequestPreview
                  | Navigate Direction
                  | EditQuery QueryEdit
                  | TerminalResized Int Int
                  | Confirm
                  | Dismiss
                  | PreviewCompleted PreviewRequest (Either PreviewError String)
     deriving (Eq, Show)

data SessionCommand = ReadPreview PreviewRequest
                    | StopSession
     deriving (Eq, Show)

newSession :: [String] -> (Int, Int) -> Session
newSession items size = Browsing (Browser (Search.newSearch items) size NoPreview 0)

sessionBrowser :: Session -> Browser
sessionBrowser (Browsing browser)   = browser
sessionBrowser (Finished _ browser) = browser

transitionSession :: SessionEvent -> Session -> (Session, [SessionCommand])
transitionSession _ state@(Finished _ _) = (state, [])
transitionSession event (Browsing browser) = case event of
  RequestPreview -> requestPreview browser
  Navigate direction ->
    requestPreview
      browser {browserSearch = Search.moveSelection direction (browserSearch browser)}
  EditQuery edit -> requestPreview browser {browserSearch = editSearch edit (browserSearch browser)}
  TerminalResized width height -> (Browsing browser {browserSize = (width, height)}, [])
  Confirm -> (Finished Confirmed browser, [StopSession])
  Dismiss -> (Finished Dismissed browser, [StopSession])
  PreviewCompleted request result -> (Browsing (completePreview request result browser), [])

editSearch :: QueryEdit -> Search -> Search
editSearch edit search = case edit of
  Append character -> Search.updateQuery (Search.query search ++ [character]) search
  Delete -> case Search.query search of
    ""    -> search
    value -> Search.updateQuery (init value) search
  Clear -> Search.updateQuery "" search

requestPreview :: Browser -> (Session, [SessionCommand])
requestPreview browser = case Search.selectedItem (browserSearch browser) of
  Nothing -> (Browsing browser {browserPreview = NoPreview}, [])
  Just path
    | previewPath (browserPreview browser) == Just path -> (Browsing browser, [])
    | otherwise ->
        let request = PreviewRequest (nextRequest browser) path
         in ( Browsing browser {browserPreview = Loading request, nextRequest = nextRequest browser + 1}
            , [ReadPreview request]
            )

previewPath :: PreviewState -> Maybe FilePath
previewPath NoPreview                         = Nothing
previewPath (Loading (PreviewRequest _ path)) = Just path
previewPath (Loaded path _)                   = Just path
previewPath (Failed path _)                   = Just path

completePreview :: PreviewRequest -> Either PreviewError String -> Browser -> Browser
completePreview request@(PreviewRequest _ path) result browser
  | browserPreview browser == Loading request =
      browser {browserPreview = either (Failed path) (Loaded path) result}
  | otherwise = browser
