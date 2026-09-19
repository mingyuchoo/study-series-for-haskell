{-# LANGUAGE DerivingStrategies #-}

-- | 브라우저 표면의 실행 설정입니다.
--
-- 환경 변수를 읽는 일은 실행 파일이 하고, 이 모듈은 읽어 온 값을 해석하기만 합니다.
-- 그래야 기본값과 잘못된 값의 처리를 @IO@ 없이 검증할 수 있습니다.
--
-- 수신 주소는 여기에 없습니다. 루프백 고정은 설정이 아니라 경계이며 바꿀 수 없습니다
-- (@docs/decisions/ADR-0004-web-surface.md@).
module Todo.Web.Config (
  WebConfig (..),
  defaultPort,
  defaultDatabasePath,
  resolveConfig,
) where

import Text.Read (readMaybe)

-- | 실행에 필요한 설정입니다.
data WebConfig = WebConfig
  { webPort :: Int
  , webDatabasePath :: FilePath
  -- ^ @cli@ 및 @api@와 공유하는 SQLite 파일입니다.
  }
  deriving stock (Eq, Show)

defaultPort :: Int
defaultPort = 8081

defaultDatabasePath :: FilePath
defaultDatabasePath = "todo.db"

-- | 환경 변수에서 읽은 원시 값을 설정으로 해석합니다.
--
-- 포트가 숫자가 아니면 기본값을 사용합니다. 기동을 거부하지 않는 이유는 이 표면이
-- 개인 도구이고, 오타 하나로 시작하지 못하는 것보다 기본 포트로 뜨는 편이 낫기
-- 때문입니다. 실제 사용 포트는 기동 로그에 출력합니다.
resolveConfig :: Maybe String -> Maybe String -> WebConfig
resolveConfig rawDatabasePath rawPort =
  WebConfig
    { webPort = maybe defaultPort id (rawPort >>= readMaybe)
    , webDatabasePath = maybe defaultDatabasePath id rawDatabasePath
    }
