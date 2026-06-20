-- 인프라 계층: 애플리케이션 설정
module Infrastructure.Config.AppConfig
  ( AppConfig (..)
  , defaultConfig
  ) where

-- 간단한 설정 레코드
data AppConfig = AppConfig
  { port   :: Int
    -- 서버 포트
  , dbPath :: FilePath
    -- SQLite DB 파일 경로
  }

-- 기본 설정 (추후 환경변수/파일 로딩으로 확장 가능)
defaultConfig :: AppConfig
defaultConfig =
  AppConfig
    { port = 8000
    , dbPath = "users.db"
    }
