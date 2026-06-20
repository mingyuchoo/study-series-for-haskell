module Main
    ( main
    ) where

import           Infrastructure.Persistence.PostgreSQL.UserRepositoryImpl (localConnString,
                                                                           migrateDB)

import           System.Environment                                       (getArgs)
import           System.IO                                                (BufferMode (NoBuffering),
                                                                           hSetBuffering,
                                                                           stdout)

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  args <- getArgs
  choose args
  where
    choose :: [String] -> IO ()
    choose [] = migrateDB localConnString
    choose (a : _)
      | a == "esq" = migrateDB localConnString -- Using same migration for now
      | otherwise = migrateDB localConnString
