{-# LANGUAGE OverloadedStrings #-}

module SyntaxHighlight
    ( detectLanguage
    , limitLines
    , limitStringLines
    , renderHighlightedContent
    , renderPlainText
    , renderPreviewContent
    ) where

import           Brick

import qualified Data.Text       as T

import           Skylighting

import           System.FilePath (takeExtension)

import           Text.Printf     (printf)

import           Types           (Name, maxPreviewLines)

detectLanguage :: FilePath -> Maybe Syntax
detectLanguage path =
  let ext = T.pack $ takeExtension path
   in lookupSyntax ext defaultSyntaxMap

limitLines :: T.Text -> [T.Text]
limitLines content = take maxPreviewLines $ T.lines content

limitStringLines :: String -> [T.Text]
limitStringLines = map T.pack . take maxPreviewLines . lines

tokenAttr :: TokenType -> AttrName
tokenAttr KeywordTok  = attrName "syntax.keyword"
tokenAttr DataTypeTok = attrName "syntax.type"
tokenAttr DecValTok   = attrName "syntax.number"
tokenAttr BaseNTok    = attrName "syntax.number"
tokenAttr FloatTok    = attrName "syntax.number"
tokenAttr ConstantTok = attrName "syntax.number"
tokenAttr CharTok     = attrName "syntax.string"
tokenAttr StringTok   = attrName "syntax.string"
tokenAttr CommentTok  = attrName "syntax.comment"
tokenAttr OtherTok    = attrName "syntax.function"
tokenAttr FunctionTok = attrName "syntax.function"
tokenAttr VariableTok = attrName "syntax.function"
tokenAttr _           = attrName "default"

renderPlainText :: [T.Text] -> Widget Name
renderPlainText textLines =
  vBox $ zipWith addLineNumber [1 ..] textLines
  where
    addLineNumber :: Int -> T.Text -> Widget Name
    addLineNumber n line =
      hBox
        [ withAttr
            (attrName "syntax.lineNumber")
            (str $ printf "%3d | " n)
        , txt line
        ]

renderTokenLine :: Int -> SourceLine -> Widget Name
renderTokenLine lineNum tokens =
  hBox
    [ withAttr
        (attrName "syntax.lineNumber")
        (str $ printf "%3d | " lineNum)
    , hBox $ map renderToken tokens
    ]
  where
    renderToken :: Token -> Widget Name
    renderToken (tokenType, text) =
      withAttr (tokenAttr tokenType) (txt text)

renderHighlightedContent :: FilePath -> T.Text -> Widget Name
renderHighlightedContent path = renderHighlightedLines path . limitLines

renderPreviewContent :: FilePath -> String -> Widget Name
renderPreviewContent path = renderHighlightedLines path . limitStringLines

renderHighlightedLines :: FilePath -> [T.Text] -> Widget Name
renderHighlightedLines path contentLines = case detectLanguage path of
  Nothing -> renderPlainText contentLines
  Just syntax ->
    let config = TokenizerConfig defaultSyntaxMap False
     in case tokenize config syntax (T.unlines contentLines) of
          Left _err         -> renderPlainText contentLines
          Right sourceLines -> vBox $ zipWith renderTokenLine [1 ..] sourceLines
