module Todo.Interface.HTTP.Server (
    mkApplication,
    mkProductionHandlerEnv,
) where

import Data.Time (getCurrentTime)
import Data.UUID.V4 (nextRandom)
import Network.Wai (Application)
import Servant (serve)
import Shared.Database (DatabaseConfig)
import Todo.Domain.TodoId (fromUUID)
import Todo.Infrastructure.Persistence.PostgresTodoRepository (postgresTodoRepository)
import Todo.Interface.HTTP.API (todoApiProxy)
import Todo.Interface.HTTP.Handler (HandlerEnv (..), todoServer)

mkApplication :: HandlerEnv -> Application
mkApplication env = serve todoApiProxy (todoServer env)

mkProductionHandlerEnv :: DatabaseConfig -> IO HandlerEnv
mkProductionHandlerEnv dbConfig =
    pure
        HandlerEnv
            { handlerRepository = postgresTodoRepository dbConfig
            , handlerGenerateTodoId = fromUUID <$> nextRandom
            , handlerCurrentTime = getCurrentTime
            }
