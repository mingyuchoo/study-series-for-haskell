module FileSearch
    ( listFilesRecursive
    , shouldExclude
    ) where

import           Control.Exception (SomeException, catch)
import           Control.Monad     (forM)

import           System.Directory  (doesDirectoryExist, listDirectory)
import           System.FilePath   (takeFileName, (</>))

-- | 제외할 디렉토리/파일 패턴 목록
excludePatterns :: [String]
excludePatterns =
  [ ".git"
  , ".stack-work"
  , "node_modules"
  , "dist"
  , "dist-newstyle"
  , "build"
  , ".cabal-sandbox"
  , "target"
  , ".idea"
  , ".vscode"
  ]

-- | 파일 또는 디렉토리 이름이 제외 패턴에 해당하는지 확인 (Pure)
-- 숨김 파일/디렉토리(.으로 시작)도 제외
shouldExclude :: FilePath -> Bool
shouldExclude path =
  let name = takeFileName path
  in name `elem` excludePatterns || (take 1 name == "." && name `notElem` [".", ".."])

-- | 재귀적으로 디렉토리 내 모든 파일 검색 (Effect)
-- 제외 패턴에 해당하는 디렉토리는 건너뛰고, 에러 발생 시 해당 경로만 건너뜀
listFilesRecursive :: FilePath -> IO [FilePath]
listFilesRecursive dir = do
  (listDirectory dir >>= processEntries dir) `catch` handleError
  where
    -- | 디렉토리 읽기 에러 처리 - 빈 리스트 반환 (Effect)
    handleError :: SomeException -> IO [FilePath]
    handleError _ = return []

    -- | 디렉토리 엔트리들을 처리 (Effect)
    processEntries :: FilePath -> [FilePath] -> IO [FilePath]
    processEntries baseDir entries = do
      paths <- forM entries $ \entry -> do
        let path = baseDir </> entry
        -- 제외 패턴에 해당하면 건너뜀
        if shouldExclude entry
          then return []
          else do
            isDir <- doesDirectoryExist path `catch` \(_ :: SomeException) -> return False
            if isDir
              then listFilesRecursive path  -- 재귀 호출
              else return [path]             -- 파일이면 추가
      return $ concat paths
