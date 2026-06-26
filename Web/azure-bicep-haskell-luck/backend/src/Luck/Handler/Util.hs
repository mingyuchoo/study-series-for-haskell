-- | 핸들러 공용 콤비네이터. 핸들러가 "배관"이 아닌 "오케스트레이션"으로 읽히도록
--   반복되는 패턴(풀에서 DB 실행, 도메인 에러 변환, 404 처리)을 한곳에 모은다.
module Luck.Handler.Util
    ( liftEither
    , note404
    , runDB
    ) where

import           Control.Monad.Except       (throwError)
import           Control.Monad.IO.Class     (liftIO)
import           Control.Monad.Reader       (ask)
import           Data.Pool                  (Pool)
import           Data.Text                  (Text)
import           Database.PostgreSQL.Simple (Connection)
import           Luck.App                   (AppEnv (..), AppM)
import           Luck.Error                 (DomainError (..))
import           Luck.Web.Error             (toServerError)

-- | 커넥션 풀을 받는 IO 동작을 환경에서 풀을 꺼내 실행한다.
runDB :: (Pool Connection -> IO a) -> AppM a
runDB f = do
  env <- ask
  liftIO (f (envPool env))

-- | 도메인 에러(@Left@)는 HTTP 에러로 던지고, @Right@ 는 그대로 통과시킨다.
liftEither :: Either DomainError a -> AppM a
liftEither = either (throwError . toServerError) pure

-- | @Nothing@ 이면 주어진 메시지로 404 를 던진다.
note404 :: Text -> Maybe a -> AppM a
note404 msg = maybe (throwError (toServerError (NotFound msg))) pure
