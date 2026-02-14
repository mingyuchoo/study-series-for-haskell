{-# LANGUAGE OverloadedStrings #-}

module SyntaxHighlight
    ( detectLanguage
    , renderHighlightedContent
    , renderPlainText
    , limitLines
    ) where

import           Brick
import qualified Data.Text          as T
import           Skylighting
import           System.FilePath    (takeExtension)
import           Text.Printf        (printf)

import           Types              (Name)

-- | 파일 확장자로 언어 감지
detectLanguage :: FilePath -> Maybe Syntax
detectLanguage path =
  let ext = T.pack $ takeExtension path
  in lookupSyntax ext defaultSyntaxMap

-- | 내용을 처음 100줄로 제한
limitLines :: T.Text -> [T.Text]
limitLines content = take 100 $ T.lines content

-- | 일반 텍스트를 라인 번호와 함께 렌더링
renderPlainText :: [T.Text] -> Widget Name
renderPlainText textLines =
  vBox $ zipWith addLineNumber [1..] textLines
  where
    addLineNumber :: Int -> T.Text -> Widget Name
    addLineNumber n line =
      hBox [ withAttr (attrName "syntax.lineNumber")
               (str $ printf "%3d | " n)
           , txt line
           ]

-- | 파일 내용을 구문 강조하여 렌더링 (임시 구현)
renderHighlightedContent :: FilePath -> T.Text -> Widget Name
renderHighlightedContent _path content = txt content
