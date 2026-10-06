module Hfm.Infrastructure.FileSearch
    ( listFilesRecursive
    , shouldExclude
    ) where

import           Control.Exception (SomeException, catch)
import           Control.Monad     (forM)

import           System.Directory  (doesDirectoryExist, listDirectory)
import           System.FilePath   ((</>))
import Hfm.Domain.SearchPolicy (shouldExclude)

-- | 재귀적으로 디렉토리 내 모든 파일 검색 (Effect)
-- 제외 패턴에 해당하는 디렉토리는 건너뛰고, 에러 발생 시 해당 경로만 건너뜀
listFilesRecursive :: FilePath -> IO [FilePath]
listFilesRecursive dir = do
  (listDirectory dir >>= processEntries dir) `catch` handleError
  where
    -- \| 디렉토리 읽기 에러 처리 - 빈 리스트 반환 (Effect)
    handleError :: SomeException -> IO [FilePath]
    handleError _ = return []

    -- \| 디렉토리 엔트리들을 처리 (Effect)
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
              then listFilesRecursive path -- 재귀 호출
              else return [path] -- 파일이면 추가
      return $ concat paths
