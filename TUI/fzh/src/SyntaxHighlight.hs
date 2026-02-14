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

-- | 토큰 타입을 속성 이름으로 매핑
tokenAttr :: TokenType -> AttrName
tokenAttr KeywordTok        = attrName "syntax.keyword"
tokenAttr DataTypeTok       = attrName "syntax.type"
tokenAttr DecValTok         = attrName "syntax.number"
tokenAttr BaseNTok          = attrName "syntax.number"
tokenAttr FloatTok          = attrName "syntax.number"
tokenAttr ConstantTok       = attrName "syntax.number"
tokenAttr CharTok           = attrName "syntax.string"
tokenAttr StringTok         = attrName "syntax.string"
tokenAttr CommentTok        = attrName "syntax.comment"
tokenAttr OtherTok          = attrName "syntax.function"
tokenAttr FunctionTok       = attrName "syntax.function"
tokenAttr VariableTok       = attrName "syntax.function"
tokenAttr _                 = attrName "default"

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

-- | 토큰 줄을 라인 번호와 함께 렌더링
renderTokenLine :: Int -> SourceLine -> Widget Name
renderTokenLine lineNum tokens =
  hBox [ withAttr (attrName "syntax.lineNumber")
           (str $ printf "%3d | " lineNum)
       , hBox $ map renderToken tokens
       ]
  where
    renderToken :: Token -> Widget Name
    renderToken (tokenType, text) =
      withAttr (tokenAttr tokenType) (txt text)

-- | 파일 내용을 구문 강조하여 렌더링
renderHighlightedContent :: FilePath -> T.Text -> Widget Name
renderHighlightedContent path content =
  let contentLines = limitLines content
  in case detectLanguage path of
       Nothing -> renderPlainText contentLines
       Just syntax ->
         let config = TokenizerConfig defaultSyntaxMap False
         in case tokenize config syntax (T.unlines contentLines) of
              Left _err -> renderPlainText contentLines
              Right sourceLines ->
                vBox $ zipWith renderTokenLine [1..] sourceLines
