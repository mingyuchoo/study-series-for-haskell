module Hfm.Domain.SearchPolicy (shouldExclude) where

import System.FilePath (takeFileName)

-- | 제외할 디렉토리/파일 패턴 목록 (숨김 파일 제외)
-- 숨김 파일/디렉토리(.으로 시작)는 별도 조건으로 처리
excludePatterns :: [String]
excludePatterns =
  [ "node_modules"
  , "dist"
  , "dist-newstyle"
  , "build"
  , "target"
  ]

-- | 파일 또는 디렉토리 이름이 제외 패턴에 해당하는지 확인 (Pure)
-- 숨김 파일/디렉토리(.으로 시작)도 제외
shouldExclude :: FilePath -> Bool
shouldExclude path =
  let name = takeFileName path
   in name `elem` excludePatterns || isHidden name
  where
    isHidden name = case name of
      '.' : _ -> name `notElem` [".", ".."]
      _       -> False

