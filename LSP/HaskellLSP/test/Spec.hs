-- {-# OPTIONS_GHC -F -pgmF doctest-discover #-}
-- {-# OPTIONS_GHC -F -pgmF hspec-discover   #-}

import Test.Hspec
import Flow ((<|))
import Lib
import LSP.Types
import LSP.Error
import Data.Aeson (encode, decode, Value(..))
import Data.List (isInfixOf)
import qualified Data.ByteString.Lazy.Char8 as L8
import Control.Exception (toException, ErrorCall(..))
import qualified DocumentSyncSpec
import qualified DiagnosticsSpec
import qualified PropertySpec
import qualified HoverSpec
import qualified CompletionSpec
import qualified DefinitionSpec

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
    describe "Document Synchronization" DocumentSyncSpec.spec
    describe "Diagnostics Engine" DiagnosticsSpec.spec
    describe "Property-Based Tests" PropertySpec.spec
    describe "Hover Handler" HoverSpec.spec
    describe "Completion Handler" CompletionSpec.spec
    describe "Definition Handler" DefinitionSpec.spec
    describe "Given Prelude" <| do
        context "when use `read` function" <| do
            it "should parse integers" <| do
                read "10" `shouldBe` (10 :: Int)
            it "should parse floating-point numbers" <| do
                read "2.5" `shouldBe` (2.5 :: Float)
    describe "Given Lib" <| do
        context "when use `cliMain` function" <| do
            it "should be available for import" <| do
              -- Test that cliMain function exists and can be referenced
              -- We don't actually run it in tests since it's designed to run as a server
              let _ = cliMain
              True `shouldBe` True
    describe "Given LSP.Types" <| do
        context "when serializing LspMessage" <| do
            it "should encode and decode RequestMessage correctly" <| do
                let msg = RequestMessage (String "1") "initialize" Null
                decode (encode msg) `shouldBe` Just msg
            it "should encode and decode NotificationMessage correctly" <| do
                let msg = NotificationMessage "initialized" Null
                decode (encode msg) `shouldBe` Just msg
        context "when using JSON-RPC protocol helpers" <| do
            it "should encode message with Content-Length header" <| do
                let msg = NotificationMessage "test" Null
                    encoded = encodeLspMessage msg
                encoded `shouldSatisfy` (\bs -> "Content-Length:" `isInfixOf` show bs)
            it "should parse Content-Length from header" <| do
                let input = L8.pack "Content-Length: 42\r\n\r\n{}"
                parseContentLength input `shouldBe` Just 42
    describe "Given LSP.Error" <| do
        context "when classifying errors" <| do
            it "should classify parse errors as recoverable" <| do
                let parseErr = toException (ErrorCall "parse error occurred")
                classifyError parseErr `shouldBe` Recoverable
            it "should classify memory errors as fatal" <| do
                let memErr = toException (ErrorCall "memory exhausted")
                classifyError memErr `shouldBe` Fatal
            it "should classify timeout errors as transient" <| do
                let timeoutErr = toException (ErrorCall "timeout occurred")
                classifyError timeoutErr `shouldBe` Transient
        context "when building error responses" <| do
            it "should create parse error with correct code" <| do
                let err = mkParseError "Invalid JSON"
                errorCode err `shouldBe` (-32700)
                errorMessage err `shouldBe` "Invalid JSON"
            it "should create method not found error" <| do
                let err = mkMethodNotFound "unknownMethod"
                errorCode err `shouldBe` (-32601)
                errorMessage err `shouldBe` "Method not found: unknownMethod"
