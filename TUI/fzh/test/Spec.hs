{-# LANGUAGE OverloadedStrings #-}

import           Test.Hspec

import qualified Data.Text     as T
import qualified Data.Vector   as Vec

import           Flow          ((<|))
import           Fuzzy         (filterItems, fuzzyMatchScore)
import           Types         (AppConfig(..), AppState(..),
                               configWithKeyBinding, defaultConfig, initialState,
                               isTerminalSizeSufficient, resultListWidth,
                               previewWidth, contentHeight)
import           Config        (KeyBindingConfig(..), KeyBindingStyle(..))
import           FileSearch    (listFilesRecursive, shouldExclude)
import           Event         (formatFileError)
import           UI            (formatInfoText)
import qualified SyntaxHighlightSpec

import           Control.Exception (IOException)
import           System.Directory (createDirectoryIfMissing, removeDirectoryRecursive,
                                  doesDirectoryExist)
import           System.FilePath  ((</>))
import           System.IO        (writeFile)
import           System.IO.Error  (mkIOError, doesNotExistErrorType,
                                  permissionErrorType, userErrorType)

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
    describe "Fuzzy 모듈" <| do
        context "fuzzyMatchScore 함수" <| do
            it "정확히 일치하는 경우 갭이 0이어야 함" <| do
                fuzzyMatchScore "test" "test" `shouldBe` Just 0

            it "부분 일치하는 경우 올바른 갭을 반환해야 함" <| do
                fuzzyMatchScore "ts" "test" `shouldBe` Just 1

            it "일치하지 않는 경우 Nothing을 반환해야 함" <| do
                fuzzyMatchScore "xyz" "test" `shouldBe` Nothing

            it "대소문자를 구분하지 않아야 함" <| do
                fuzzyMatchScore "TeSt" "TEST" `shouldBe` Just 0

        context "filterItems 함수" <| do
            it "빈 쿼리의 경우 모든 아이템을 반환해야 함" <| do
                let items = Vec.fromList ["test", "best", "rest"]
                Vec.length (filterItems "" items) `shouldBe` 3

            it "매칭되는 아이템만 반환해야 함" <| do
                let items = Vec.fromList ["test", "toast", "xyz"]
                let filtered = filterItems "ts" items
                Vec.length filtered `shouldBe` 2

    describe "Types 모듈" <| do
        context "initialState 함수" <| do
            it "초기 상태를 올바르게 생성해야 함" <| do
                let items = ["item1", "item2"]
                let state = initialState items defaultConfig (80, 24)
                Vec.length (stItems state) `shouldBe` 2
                stSearchQuery state `shouldBe` ""

            it "터미널 크기를 포함한 초기 상태를 올바르게 생성해야 함" <| do
                let items = ["file1.txt", "file2.txt"]
                let cfg = defaultConfig
                let termSize = (100, 30)
                let state = initialState items cfg termSize
                stTerminalSize state `shouldBe` (100, 30)

        context "configWithKeyBinding 함수" <| do
            it "키바인딩 설정을 올바르게 적용해야 함" <| do
                let kbConfig = KeyBindingConfig { bindingStyle = Vim }
                let config = configWithKeyBinding kbConfig
                configKeyBinding config `shouldBe` Vim

        context "isTerminalSizeSufficient 함수" <| do
            it "최소 크기(80x24)를 충족하면 True를 반환해야 함" <| do
                isTerminalSizeSufficient (80, 24) `shouldBe` True

            it "최소 너비(80) 미만이면 False를 반환해야 함" <| do
                isTerminalSizeSufficient (79, 24) `shouldBe` False

            it "최소 높이(24) 미만이면 False를 반환해야 함" <| do
                isTerminalSizeSufficient (80, 23) `shouldBe` False

            it "큰 크기(200x50)를 충족하면 True를 반환해야 함" <| do
                isTerminalSizeSufficient (200, 50) `shouldBe` True

        context "resultListWidth 함수" <| do
            it "전체 너비의 40%를 반환해야 함" <| do
                resultListWidth 100 `shouldBe` 40

            it "작은 너비에서도 올바른 비율을 계산해야 함" <| do
                resultListWidth 50 `shouldBe` 20

            it "큰 너비에서도 올바른 비율을 계산해야 함" <| do
                resultListWidth 200 `shouldBe` 80

        context "previewWidth 함수" <| do
            it "전체 너비의 60%를 반환해야 함" <| do
                previewWidth 100 `shouldBe` 60

            it "resultListWidth와 합쳐서 전체 너비가 되어야 함" <| do
                let w = 100
                resultListWidth w + previewWidth w `shouldBe` w

            it "다양한 너비에서 합이 전체가 되어야 함" <| do
                let w = 150
                resultListWidth w + previewWidth w `shouldBe` w

        context "contentHeight 함수" <| do
            it "전체 높이에서 고정 요소들을 제외한 값을 반환해야 함" <| do
                contentHeight 30 `shouldBe` 22  -- 30 - 3 - 3 - 2

            it "최소 높이(24)에서 올바른 값을 반환해야 함" <| do
                contentHeight 24 `shouldBe` 16  -- 24 - 3 - 3 - 2

            it "큰 높이에서도 올바른 값을 반환해야 함" <| do
                contentHeight 50 `shouldBe` 42  -- 50 - 3 - 3 - 2

    describe "FileSearch 모듈" <| do
        context "shouldExclude 함수" <| do
            it ".git 디렉토리를 제외해야 함" <| do
                shouldExclude ".git" `shouldBe` True

            it ".stack-work 디렉토리를 제외해야 함" <| do
                shouldExclude ".stack-work" `shouldBe` True

            it "node_modules 디렉토리를 제외해야 함" <| do
                shouldExclude "node_modules" `shouldBe` True

            it "일반 디렉토리는 제외하지 않아야 함" <| do
                shouldExclude "src" `shouldBe` False

            it "숨김 파일은 제외해야 함" <| do
                shouldExclude ".hidden" `shouldBe` True

        context "listFilesRecursive 함수" <| do
            it "제외 패턴에 해당하는 디렉토리를 건너뛰어야 함" <| do
                -- 테스트 디렉토리 구조 생성
                let testDir = "/tmp/fzh-test"
                createDirectoryIfMissing True <| testDir </> "src"
                createDirectoryIfMissing True <| testDir </> ".git"
                createDirectoryIfMissing True <| testDir </> ".stack-work"
                writeFile (testDir </> "src/Main.hs") "module Main where"
                writeFile (testDir </> ".git/config") "git config"
                writeFile (testDir </> ".stack-work/build") "build"

                -- 파일 목록 가져오기
                files <- listFilesRecursive testDir

                -- 정리
                dirExists <- doesDirectoryExist testDir
                if dirExists then removeDirectoryRecursive testDir else return ()

                -- 검증: src/Main.hs만 포함되어야 함
                length files `shouldBe` 1
                head files `shouldBe` (testDir </> "src/Main.hs")

    describe "Event 모듈" <| do
        context "formatFileError 함수" <| do
            it "파일이 존재하지 않을 때 명확한 메시지를 반환해야 함" <| do
                let err = mkIOError doesNotExistErrorType "test" Nothing (Just "test.txt")
                formatFileError err `shouldBe` "파일이 존재하지 않습니다"

            it "권한이 없을 때 명확한 메시지를 반환해야 함" <| do
                let err = mkIOError permissionErrorType "test" Nothing (Just "test.txt")
                formatFileError err `shouldBe` "파일 읽기 권한이 없습니다"

            it "기타 에러일 때 상세 메시지를 반환해야 함" <| do
                let err = mkIOError userErrorType "custom error" Nothing (Just "test.txt")
                T.isPrefixOf "파일 읽기 오류: " (formatFileError err) `shouldBe` True

    describe "UI 모듈" <| do
        context "formatInfoText 함수" <| do
            it "선택 없이 아이템만 있을 때" <| do
                formatInfoText 10 Nothing `shouldBe` "Items: 10"

            it "선택이 있을 때 위치를 표시해야 함" <| do
                formatInfoText 10 (Just 3) `shouldBe` "Items: 10 | Position: 4/10"

            it "아이템이 0개일 때" <| do
                formatInfoText 0 Nothing `shouldBe` "Items: 0"

            it "첫 번째 아이템 선택 시" <| do
                formatInfoText 5 (Just 0) `shouldBe` "Items: 5 | Position: 1/5"

            it "마지막 아이템 선택 시" <| do
                formatInfoText 5 (Just 4) `shouldBe` "Items: 5 | Position: 5/5"

    SyntaxHighlightSpec.spec
