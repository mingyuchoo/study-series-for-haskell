module Hfm.DevTools.Architecture
  ( Workspace
  , workspaceFolders
  , checkWorkspace
  ) where

import           Data.Char  (isAlphaNum, isLower, isSpace, isUpper)
import           Data.List  (intercalate, isPrefixOf, nub, sort, (\\))
import           Data.Maybe (isJust)

type Workspace = [(FilePath, String)]

packageRules :: [(String, [String], [String])]
packageRules =
  [ ("hfm-domain", ["Domain"], [])
  , ("hfm-application", ["Domain", "Application"], ["hfm-domain"])
  , ("hfm-infrastructure", ["Domain", "Application", "Infrastructure"], ["hfm-domain", "hfm-application"])
  , ("hfm-tui", ["Domain", "Application", "Tui"], ["hfm-domain", "hfm-application"])
  , ("hfm", ["Domain", "Application", "Infrastructure", "Tui"], ["hfm-domain", "hfm-application", "hfm-infrastructure", "hfm-tui"])
  , ("hfm-dev-tools", ["DevTools"], ["hfm-dev-tools"])
  ]

workspaceFolders :: [FilePath]
workspaceFolders = map (packageFolder . first) packageRules
  where
    first (name, _, _) = name

packageFolder :: String -> FilePath
packageFolder "hfm" = "apps/hfm"
packageFolder name  = "packages/" ++ name

checkWorkspace :: Workspace -> [String]
checkWorkspace workspace = concatMap checkRegistration ["stack.yaml", "cabal.project"] ++ concatMap checkPackage packageRules
  where
    checkRegistration path = case lookup path workspace of
      Nothing -> [path ++ " missing"]
      Just contents ->
        let paths = nub [entry | line <- lines contents, let entry = trim (dropDash (trim line)), any (`isPrefixOf` entry) ["packages/", "apps/"]]
            difference = sort ((paths \\ workspaceFolders) ++ (workspaceFolders \\ paths))
        in [path ++ " workspace mismatch: " ++ show difference | not (null difference)]
    checkPackage (name, layers, allowed) =
      let folder = packageFolder name
          manifestPath = folder ++ "/package.yaml"
          sourceRoot = folder ++ if name == "hfm" then "/app/" else "/src/"
          sources = [(path, contents) | (path, contents) <- workspace, sourceRoot `isPrefixOf` path]
          checkManifest = case lookup manifestPath workspace of
            Nothing -> [manifestPath ++ " missing"]
            Just contents -> checkDependencies name allowed (dependencies contents)
      in checkManifest ++ concat [checkSource name layers (moduleName (drop (length sourceRoot) path)) path contents | (path, contents) <- sources]

dependencies :: String -> [String]
dependencies = nub . concatMap dependency . takeWhile (not . isPrefixOf "tests:") . lines
  where
    dependency line = case words (trim line) of
      "-" : name : _ | validName name -> [name]
      _                               -> []
    validName [] = False
    validName name@(first : _) = isLower first && all (\character -> isAlphaNum character || character `elem` "-_") name

checkDependencies :: String -> [String] -> [String] -> [String]
checkDependencies package allowed declared =
  [package ++ " has forbidden dependency " ++ dependency | dependency <- declared, dependency `elem` localPackages, dependency `notElem` allowed] ++
  [package ++ " has effect/framework dependency " ++ dependency | Just permitted <- [innerDependencies package], dependency <- declared, dependency `notElem` permitted]
  where
    localPackages = [name | (name, _, _) <- packageRules]

innerDependencies :: String -> Maybe [String]
innerDependencies "hfm-domain" = Just ["base", "text", "vector", "filepath"]
innerDependencies "hfm-application" = Just ["base", "hfm-domain", "text", "bytestring", "filepath", "mtl", "transformers"]
innerDependencies _ = Nothing

checkSource :: String -> [String] -> String -> FilePath -> String -> [String]
checkSource package layers sourceModule path contents = concatMap checkImport (imports tokens) ++ concreteEffects ++ executablePorts
  where
    tokens = tokenize (stripComments contents)
    identifiers = concatMap (words . map (\character -> if character == '.' then ' ' else character)) (filter (not . isPrefixOf "\"") tokens)
    inner = isJust (innerDependencies package)
    purePlan = package == "hfm-application" && sourceModule `notElem` ["Hfm.Application.Effects.Ports", "Hfm.Application.Effects.Runtime"]
    forbidden = ["Brick", "Graphics.Vty", "System.Directory", "System.IO", "System.Posix", "System.Environment", "Data.Yaml", "Control.Monad.IO.Class", "System.Process", "GHC.IO"]
    checkImport imported =
      [path ++ " imports forbidden " ++ imported | "Hfm." `isPrefixOf` imported, takeWhile (/= '.') (drop 4 imported) `notElem` layers] ++
      [path ++ " imports effect/framework module " ++ imported | inner, any (`modulePrefix` imported) forbidden] ++
      [path ++ " imports " ++ role imported ++ " instead of describing requests" | purePlan, "Hfm.Application.Effects" `modulePrefix` imported]
    role imported = if imported == "Hfm.Application.Effects.Runtime" then "effect interpreter" else "executable ports"
    concreteEffects = [path ++ " contains concrete IO or FFI" | inner, any (`elem` identifiers) ["IO", "unsafePerformIO", "unsafeInterleaveIO", "foreign"]]
    executablePorts = [path ++ " accesses executable ports instead of describing requests" | purePlan, any (`elem` identifiers) ["FileSystem", "Processes"]]

modulePrefix :: String -> String -> Bool
modulePrefix prefix name = name == prefix || (prefix ++ ".") `isPrefixOf` name

moduleName :: FilePath -> String
moduleName = intercalate "." . words . map (\character -> if character `elem` "/\\" then ' ' else character) . reverse . drop 3 . reverse

imports :: [String] -> [String]
imports [] = []
imports ("import" : rest) = case dropWhile modifier rest of
  name@(first : _) : remaining | isUpper first -> name : imports remaining
  remaining                                    -> imports remaining
  where
    modifier token = token `elem` ["qualified", "safe"] || "\"" `isPrefixOf` token
imports (_ : rest) = imports rest

tokenize :: String -> [String]
tokenize [] = []
tokenize ('"' : rest) = let (quoted, remaining) = stringLiteral rest in ('"' : quoted) : tokenize remaining
tokenize source@(first : rest)
  | isAlphaNum first || first == '_' = let (token, remaining) = span (\character -> isAlphaNum character || character `elem` "_.'") source in token : tokenize remaining
  | otherwise = tokenize rest

stringLiteral :: String -> (String, String)
stringLiteral [] = ([], [])
stringLiteral ('\\' : character : rest) = let (quoted, remaining) = stringLiteral rest in ('\\' : character : quoted, remaining)
stringLiteral ('"' : rest) = ("\"", rest)
stringLiteral (character : rest) = let (quoted, remaining) = stringLiteral rest in (character : quoted, remaining)

stripComments :: String -> String
stripComments [] = []
stripComments ('\'' : rest)
  | Just remaining <- characterLiteralRest rest = ' ' : stripComments remaining
stripComments ('-' : '-' : rest) = stripComments (dropWhile (/= '\n') rest)
stripComments ('{' : '-' : rest) = ' ' : block (1 :: Int) rest
  where
    block _ []                          = []
    block depth ('{' : '-' : remaining) = block (depth + 1) remaining
    block 1 ('-' : '}' : remaining)     = stripComments remaining
    block depth ('-' : '}' : remaining) = block (depth - 1) remaining
    block depth ('\n' : remaining)      = '\n' : block depth remaining
    block depth (_ : remaining)         = block depth remaining
stripComments ('"' : rest) = let (quoted, remaining) = stringLiteral rest in '"' : quoted ++ stripComments remaining
stripComments (character : rest) = character : stripComments rest

characterLiteralRest :: String -> Maybe String
characterLiteralRest ('\\' : '\'' : '\'' : rest) = Just rest
characterLiteralRest ('\\' : rest) = case break (\character -> character == '\'' || character == '\n') rest of
  (_, '\'' : remaining) -> Just remaining
  _                     -> Nothing
characterLiteralRest (character : '\'' : rest)
  | character /= '\'' && character /= '\n' = Just rest
characterLiteralRest _ = Nothing

trim :: String -> String
trim = reverse . dropWhile isSpace . reverse . dropWhile isSpace

dropDash :: String -> String
dropDash ('-' : rest) = rest
dropDash value        = value
