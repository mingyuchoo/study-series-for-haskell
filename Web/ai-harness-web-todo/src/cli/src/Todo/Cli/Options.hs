{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedStrings #-}

-- | 명령줄 문법 정의입니다.
--
-- 이 모듈은 문자열을 도메인 어휘로 바꾸는 일만 하고 비즈니스 규칙을 갖지 않습니다.
-- 상태와 우선순위 이름은 "Todo.Core.Types"의 안정적인 이름을 그대로 사용하므로
-- CLI와 HTTP API가 같은 어휘를 노출합니다.
module Todo.Cli.Options (
  Options (..),
  Command (..),
  AddOptions (..),
  ListOptions (..),
  EditOptions (..),
  optionsParser,
  optionsParserInfo,
) where

import Data.List (intercalate)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day)
import Data.Time.Format.ISO8601 (iso8601ParseM)
import Options.Applicative
import Todo.Core.Filter (SortOrder (..))
import Todo.Core.Types (
  Priority (..),
  Status,
  priorityFromName,
  priorityName,
  statusFromName,
  statusName,
 )

-- | 전역 옵션과 실행할 명령입니다.
data Options = Options
  { optDatabase :: Maybe FilePath
  -- ^ @--db@로 지정한 경로입니다. 'Nothing'이면 환경 변수와 기본값을 사용합니다.
  , optCommand :: Command
  }
  deriving stock (Eq, Show)

-- | 실행할 명령입니다.
data Command
  = CmdAdd AddOptions
  | CmdList ListOptions
  | CmdStart Int
  | CmdDone Int
  | CmdReopen Int
  | CmdArchive Int
  | CmdRemove Int
  | CmdEdit Int EditOptions
  deriving stock (Eq, Show)

-- | @add@ 명령의 입력입니다.
data AddOptions = AddOptions
  { addTitle :: Text
  , addList :: Maybe Text
  , addPriority :: Priority
  , addTags :: [Text]
  , addDue :: Maybe Day
  }
  deriving stock (Eq, Show)

-- | @list@ 명령의 입력입니다.
data ListOptions = ListOptions
  { listStatus :: Maybe Status
  -- ^ 지정하지 않으면 끝나지 않은 할 일만 봅니다.
  , listAll :: Bool
  , listTags :: [Text]
  , listList :: Maybe Text
  , listDueOnOrBefore :: Maybe Day
  , listSort :: SortOrder
  }
  deriving stock (Eq, Show)

-- | @edit@ 명령의 입력입니다. 지정하지 않은 필드는 바뀌지 않습니다.
data EditOptions = EditOptions
  { editTitle :: Maybe Text
  , editList :: Maybe Text
  , editPriority :: Maybe Priority
  , editTags :: [Text]
  , editClearTags :: Bool
  , editDue :: Maybe Day
  , editClearDue :: Bool
  }
  deriving stock (Eq, Show)

-- | 실행 파일이 사용하는 최상위 파서입니다.
optionsParserInfo :: ParserInfo Options
optionsParserInfo =
  info
    (optionsParser <**> helper)
    ( fullDesc
        <> progDesc "로컬 SQLite 파일에 저장하는 할 일 관리 도구"
        <> header "cli - Todo List"
    )

optionsParser :: Parser Options
optionsParser =
  Options
    <$> optional
      ( strOption
          ( long "db"
              <> metavar "PATH"
              <> help "SQLite 파일 경로. 기본값은 TODO_DB 환경 변수 또는 ./todo.db"
          )
      )
    <*> commandParser

commandParser :: Parser Command
commandParser =
  hsubparser
    ( command "add" (info (CmdAdd <$> addParser) (progDesc "할 일을 추가합니다"))
        <> command "list" (info (CmdList <$> listParser) (progDesc "할 일을 조회합니다"))
        <> command "start" (info (CmdStart <$> todoIdArg) (progDesc "진행 중으로 표시합니다"))
        <> command "done" (info (CmdDone <$> todoIdArg) (progDesc "완료로 표시합니다"))
        <> command "reopen" (info (CmdReopen <$> todoIdArg) (progDesc "대기 상태로 되돌립니다"))
        <> command "archive" (info (CmdArchive <$> todoIdArg) (progDesc "보관합니다"))
        <> command "rm" (info (CmdRemove <$> todoIdArg) (progDesc "영구 삭제합니다"))
        <> command "edit" (info (CmdEdit <$> todoIdArg <*> editParser) (progDesc "내용을 수정합니다"))
    )

todoIdArg :: Parser Int
todoIdArg = argument auto (metavar "ID" <> help "할 일 식별자")

addParser :: Parser AddOptions
addParser =
  AddOptions
    <$> strArgument (metavar "TITLE" <> help "할 일 제목")
    <*> optional (strOption (long "list" <> metavar "NAME" <> help "목록 이름"))
    <*> option
      priorityReader
      ( long "priority"
          <> metavar "PRIORITY"
          <> value defaultPriority
          <> showDefaultWith (T.unpack . priorityName)
          <> help ("우선순위: " <> priorityChoices)
      )
    <*> many (strOption (long "tag" <> metavar "TAG" <> help "태그. 여러 번 지정할 수 있습니다"))
    <*> optional (option dayReader (long "due" <> metavar "YYYY-MM-DD" <> help "마감일"))

listParser :: Parser ListOptions
listParser =
  ListOptions
    <$> optional
      ( option
          statusReader
          ( long "status"
              <> metavar "STATUS"
              <> help ("상태로 걸러냅니다: " <> statusChoices)
          )
      )
    <*> switch (long "all" <> help "완료와 보관을 포함한 모든 할 일을 봅니다")
    <*> many (strOption (long "tag" <> metavar "TAG" <> help "이 태그를 모두 가진 할 일만 봅니다"))
    <*> optional (strOption (long "list" <> metavar "NAME" <> help "목록으로 걸러냅니다"))
    <*> optional
      ( option
          dayReader
          (long "due-before" <> metavar "YYYY-MM-DD" <> help "이 날짜 이하의 마감일만 봅니다")
      )
    <*> option
      sortReader
      ( long "sort"
          <> metavar "ORDER"
          <> value ByDueDate
          <> showDefaultWith (const "due")
          <> help "정렬 기준: due, priority, created"
      )

editParser :: Parser EditOptions
editParser =
  EditOptions
    <$> optional (strOption (long "title" <> metavar "TITLE" <> help "새 제목"))
    <*> optional (strOption (long "list" <> metavar "NAME" <> help "새 목록"))
    <*> optional
      (option priorityReader (long "priority" <> metavar "PRIORITY" <> help ("우선순위: " <> priorityChoices)))
    <*> many (strOption (long "tag" <> metavar "TAG" <> help "태그를 이 목록으로 교체합니다"))
    <*> switch (long "clear-tags" <> help "모든 태그를 제거합니다")
    <*> optional (option dayReader (long "due" <> metavar "YYYY-MM-DD" <> help "새 마감일"))
    <*> switch (long "clear-due" <> help "마감일을 제거합니다")

-- | @--priority@를 생략했을 때 사용하는 우선순위입니다.
defaultPriority :: Priority
defaultPriority = Normal

-- 읽기 함수 ------------------------------------------------------------------

dayReader :: ReadM Day
dayReader = eitherReader $ \raw ->
  case iso8601ParseM raw of
    Just day -> Right day
    Nothing -> Left ("날짜는 YYYY-MM-DD 형식이어야 합니다: " <> raw)

statusReader :: ReadM Status
statusReader = eitherReader $ \raw ->
  case statusFromName (T.pack raw) of
    Just status -> Right status
    Nothing -> Left ("알 수 없는 상태입니다: " <> raw <> ". 가능한 값: " <> statusChoices)

priorityReader :: ReadM Priority
priorityReader = eitherReader $ \raw ->
  case priorityFromName (T.pack raw) of
    Just priority -> Right priority
    Nothing -> Left ("알 수 없는 우선순위입니다: " <> raw <> ". 가능한 값: " <> priorityChoices)

sortReader :: ReadM SortOrder
sortReader = eitherReader $ \raw ->
  case raw of
    "due" -> Right ByDueDate
    "priority" -> Right ByPriority
    "created" -> Right ByCreatedAt
    _ -> Left ("알 수 없는 정렬 기준입니다: " <> raw <> ". 가능한 값: due, priority, created")

statusChoices :: String
statusChoices = intercalate ", " [T.unpack (statusName s) | s <- [minBound .. maxBound]]

priorityChoices :: String
priorityChoices = intercalate ", " [T.unpack (priorityName p) | p <- [minBound .. maxBound]]
