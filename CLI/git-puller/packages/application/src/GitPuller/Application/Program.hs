{-# LANGUAGE GADTs #-}

module GitPuller.Application.Program
  ( Request (..)
  , Program (..)
  , await
  , report
  , concurrently
  , exclusively
  ) where

import Control.Monad (ap, liftM, (>=>))
import GitPuller.Application.Event (Event)
import GitPuller.Domain.Discovery (Entry)
import GitPuller.Domain.Repository (Inspection)

data Request reply where ListDirectory :: FilePath -> Request (Either String [Entry])
                         InspectRepository :: FilePath -> Request (Either String Inspection)
                         Pull :: FilePath -> Request (Either String ())
                         Report :: Event -> Request ()

deriving instance Eq (Request reply)

deriving instance Show (Request reply)

data Program result where Finished :: result -> Program result
                          Await :: Request reply -> (reply -> Program result) -> Program result
                          Concurrently :: [Program item] -> ([item] -> Program result) -> Program result
                          Exclusively :: FilePath -> Program item -> (item -> Program result) -> Program result

instance Functor Program where
  fmap = liftM

instance Applicative Program where
  pure = Finished
  (<*>) = ap

instance Monad Program where
  Finished result >>= next = next result
  Await request resume >>= next = Await request (resume >=> next)
  Concurrently programs resume >>= next = Concurrently programs (resume >=> next)
  Exclusively resource program resume >>= next = Exclusively resource program (resume >=> next)

await :: Request reply -> Program reply
await request = Await request Finished

report :: Event -> Program ()
report = await . Report

concurrently :: [Program item] -> Program [item]
concurrently programs = Concurrently programs Finished

exclusively :: FilePath -> Program item -> Program item
exclusively resource program = Exclusively resource program Finished
