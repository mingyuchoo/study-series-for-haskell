-- | cli 실행 파일의 진입점입니다.
--
-- 옵션을 읽어 "Todo.Cli.Run"에 넘기는 일만 합니다. 로직은 라이브러리에 두어
-- 테스트할 수 있게 유지합니다.
module Main (main) where

import Options.Applicative (execParser)
import Todo.Cli.Options (optionsParserInfo)
import Todo.Cli.Run (runCli)

main :: IO ()
main = execParser optionsParserInfo >>= runCli
