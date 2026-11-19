module Fzh.Domain.Discovery
    ( Discovery
    , DiscoveryCommand (..)
    , DiscoveryEvent (..)
    , DiscoveryIssue (..)
    , EntryKind (..)
    , discoveryResult
    , shouldExclude
    , startDiscovery
    , transitionDiscovery
    ) where

data Discovery = Inspecting FilePath [FilePath] [FilePath] [DiscoveryIssue]
               | Listing FilePath [FilePath] [FilePath] [DiscoveryIssue]
               | DiscoveryFinished [FilePath] [DiscoveryIssue]
     deriving (Eq, Show)

data EntryKind = RegularFile | Directory | SymbolicLink
     deriving (Eq, Show)

data DiscoveryIssue = DiscoveryIssue FilePath String
     deriving (Eq, Show)

data DiscoveryEvent = PathInspected FilePath (Either String EntryKind)
                    | DirectoryRead FilePath (Either String [(FilePath, String)])
     deriving (Eq, Show)

data DiscoveryCommand = InspectPath FilePath
                      | ReadDirectory FilePath
     deriving (Eq, Show)

startDiscovery :: FilePath -> (Discovery, [DiscoveryCommand])
startDiscovery root = (Listing root [] [] [], [ReadDirectory root])

transitionDiscovery :: DiscoveryEvent -> Discovery -> (Discovery, [DiscoveryCommand])
transitionDiscovery event state = case (event, state) of
  (PathInspected path result, Inspecting expected pending files issues)
    | path == expected -> case result of
        Left problem -> advance pending files (DiscoveryIssue path problem : issues)
        Right RegularFile -> advance pending (path : files) issues
        Right Directory -> (Listing path pending files issues, [ReadDirectory path])
        Right SymbolicLink -> advance pending files issues
  (DirectoryRead path result, Listing expected pending files issues)
    | path == expected -> case result of
        Left problem -> advance pending files (DiscoveryIssue path problem : issues)
        Right entries ->
          advance
            ([entry | (entry, name) <- entries, not (shouldExclude name)] ++ pending)
            files
            issues
  _ -> (state, [])

advance :: [FilePath] -> [FilePath] -> [DiscoveryIssue] -> (Discovery, [DiscoveryCommand])
advance [] files issues = (DiscoveryFinished (reverse files) (reverse issues), [])
advance (path : pending) files issues = (Inspecting path pending files issues, [InspectPath path])

discoveryResult :: Discovery -> Maybe ([FilePath], [DiscoveryIssue])
discoveryResult (DiscoveryFinished files issues) = Just (files, issues)
discoveryResult _                                = Nothing

shouldExclude :: String -> Bool
shouldExclude name = name `elem` ["node_modules", "dist", "dist-newstyle", "build", "target"] || hidden name
  where
    hidden ('.' : rest) = rest `notElem` ["", "."]
    hidden _            = False
