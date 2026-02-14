{-# LANGUAGE OverloadedStrings #-}

module SyntaxHighlight
    ( detectLanguage
    , renderHighlightedContent
    ) where

import           Brick
import qualified Data.Text          as T
import           Skylighting
import           System.FilePath    (takeExtension)

import           Types              (Name)

-- | 파일 확장자로 언어 감지
detectLanguage :: FilePath -> Maybe Syntax
detectLanguage path =
  let ext = T.pack $ takeExtension path
  in lookupSyntax ext defaultSyntaxMap

-- | 파일 내용을 구문 강조하여 렌더링 (임시 구현)
renderHighlightedContent :: FilePath -> T.Text -> Widget Name
renderHighlightedContent _path content = txt content
