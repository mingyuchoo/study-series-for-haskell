{-# LANGUAGE GADTs #-}

module GitPuller.Application.UpdateWorktrees (
  start,
  perform,
)
where

import Data.List (sortOn)
import GitPuller.Application.Event (Event (..))
import GitPuller.Application.Interaction.Survey (survey)
import GitPuller.Application.Interaction.Update (update)
import GitPuller.Application.Program (Program, Request (..), concurrently, report)
import GitPuller.Application.Roles (Cast)
import GitPuller.Application.Roles qualified as Roles
import GitPuller.Domain.Outcome (Outcome (..))
import GitPuller.Domain.Update (Mode)

start :: Mode -> FilePath -> Program [Outcome]
start mode root = do
  found <- survey root
  report (Processing (length found))
  sortOn path <$> concurrently (map (update mode) found)

perform :: Cast effect -> Request reply -> effect reply
perform cast request = case request of
  ListDirectory location -> Roles.listDirectory (Roles.surveyor cast) location
  InspectRepository location -> Roles.inspectRepository (Roles.inspector cast) location
  Pull location -> Roles.pull (Roles.updater cast) location
  Report event -> Roles.notify (Roles.observer cast) event
