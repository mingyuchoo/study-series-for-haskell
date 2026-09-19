{-# LANGUAGE OverloadedStrings #-}

-- | 명령줄 문법 검증입니다.
module Todo.Cli.OptionsSpec (spec) where

import Data.Time (fromGregorian)
import Options.Applicative (defaultPrefs, execParserPure, getParseResult)
import Test.Hspec (Spec, describe, it, shouldBe)
import Todo.Cli.Options (
  AddOptions (..),
  Command (..),
  EditOptions (..),
  ListOptions (..),
  Options (..),
  optionsParserInfo,
 )
import Todo.Core.Filter (SortOrder (..))
import Todo.Core.Types (Priority (..), Status (..))

parseArgs :: [String] -> Maybe Options
parseArgs = getParseResult . execParserPure defaultPrefs optionsParserInfo

spec :: Spec
spec = describe "Todo.Cli.Options" $ do
  it "add는 제목만으로 실행할 수 있다" $
    fmap optCommand (parseArgs ["add", "보고서 작성"])
      `shouldBe` Just
        ( CmdAdd
            AddOptions
              { addTitle = "보고서 작성"
              , addList = Nothing
              , addPriority = Normal
              , addTags = []
              , addDue = Nothing
              }
        )

  it "add의 태그 옵션은 여러 번 지정할 수 있다" $
    let command = parseArgs ["add", "제목", "--tag", "work", "--tag", "home"]
     in fmap optCommand command
          `shouldBe` Just
            ( CmdAdd
                AddOptions
                  { addTitle = "제목"
                  , addList = Nothing
                  , addPriority = Normal
                  , addTags = ["work", "home"]
                  , addDue = Nothing
                  }
            )

  it "add는 마감일과 우선순위를 읽는다" $
    let command = parseArgs ["add", "제목", "--due", "2026-09-01", "--priority", "urgent"]
     in fmap optCommand command
          `shouldBe` Just
            ( CmdAdd
                AddOptions
                  { addTitle = "제목"
                  , addList = Nothing
                  , addPriority = Urgent
                  , addTags = []
                  , addDue = Just (fromGregorian 2026 9 1)
                  }
            )

  it "잘못된 날짜 형식을 거부한다" $
    parseArgs ["add", "제목", "--due", "2026/09/01"] `shouldBe` Nothing

  it "알 수 없는 우선순위를 거부한다" $
    parseArgs ["add", "제목", "--priority", "critical"] `shouldBe` Nothing

  it "list의 기본 정렬은 마감일 순이다" $
    fmap optCommand (parseArgs ["list"])
      `shouldBe` Just
        ( CmdList
            ListOptions
              { listStatus = Nothing
              , listAll = False
              , listTags = []
              , listList = Nothing
              , listDueOnOrBefore = Nothing
              , listSort = ByDueDate
              }
        )

  it "list는 상태와 정렬 기준을 읽는다" $
    let command = parseArgs ["list", "--status", "done", "--sort", "priority"]
     in fmap optCommand command
          `shouldBe` Just
            ( CmdList
                ListOptions
                  { listStatus = Just Done
                  , listAll = False
                  , listTags = []
                  , listList = Nothing
                  , listDueOnOrBefore = Nothing
                  , listSort = ByPriority
                  }
            )

  it "전역 --db 옵션을 읽는다" $
    fmap optDatabase (parseArgs ["--db", "/tmp/todo.db", "list"])
      `shouldBe` Just (Just "/tmp/todo.db")

  it "상태 변경 명령은 식별자를 받는다" $ do
    fmap optCommand (parseArgs ["done", "7"]) `shouldBe` Just (CmdDone 7)
    fmap optCommand (parseArgs ["start", "7"]) `shouldBe` Just (CmdStart 7)
    fmap optCommand (parseArgs ["reopen", "7"]) `shouldBe` Just (CmdReopen 7)
    fmap optCommand (parseArgs ["archive", "7"]) `shouldBe` Just (CmdArchive 7)
    fmap optCommand (parseArgs ["rm", "7"]) `shouldBe` Just (CmdRemove 7)

  it "edit은 마감일 제거와 태그 제거를 구분해 표현한다" $
    fmap optCommand (parseArgs ["edit", "3", "--clear-due", "--clear-tags"])
      `shouldBe` Just
        ( CmdEdit
            3
            EditOptions
              { editTitle = Nothing
              , editList = Nothing
              , editPriority = Nothing
              , editTags = []
              , editClearTags = True
              , editDue = Nothing
              , editClearDue = True
              }
        )

  it "식별자가 숫자가 아니면 거부한다" $
    parseArgs ["done", "abc"] `shouldBe` Nothing

  it "알 수 없는 명령을 거부한다" $
    parseArgs ["frobnicate"] `shouldBe` Nothing
