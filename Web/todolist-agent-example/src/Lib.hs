module Lib (
    app,
) where

import Network.Wai (Application)
import Todo.Interface.HTTP.Handler (HandlerEnv)
import Todo.Interface.HTTP.Server (mkApplication)

app :: HandlerEnv -> Application
app = mkApplication
