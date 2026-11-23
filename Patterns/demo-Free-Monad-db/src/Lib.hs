module Lib
  ( App
  , AppF (..)
  , getUser
  , logMsg
  , program
  , runApp
  , someFunc
  ) where

import Control.Monad.Free

data AppF next
  = LogMsg String next
  | GetUser Int (String -> next)
  deriving (Functor)

type App = Free AppF

logMsg :: String -> App ()
logMsg msg = liftF (LogMsg msg ())

getUser :: Int -> App String
getUser uid = liftF (GetUser uid id)

program :: App ()
program = do
  logMsg "Starting Free Monad app..."
  user <- getUser 99
  logMsg $ "Got user: " ++ user

runApp :: App a -> IO a
runApp (Pure a) = return a
runApp (Free (LogMsg msg next)) = do
  putStrLn $ "[FreeLog] " ++ msg
  runApp next
runApp (Free (GetUser uid next)) = do
  putStrLn "Querying DB..."
  let user = "User_" ++ show uid
  runApp (next user)

someFunc :: IO ()
someFunc = runApp program
