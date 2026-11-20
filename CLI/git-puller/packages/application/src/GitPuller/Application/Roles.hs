module GitPuller.Application.Roles (
  Surveyor (..),
  Inspector (..),
  Updater (..),
  Observer (..),
  Cast (..),
)
where

import GitPuller.Application.Event (Event)
import GitPuller.Domain.Discovery (Entry)
import GitPuller.Domain.Repository (Inspection)

newtype Surveyor effect = Surveyor
  { listDirectory :: FilePath -> effect (Either String [Entry])
  }

newtype Inspector effect = Inspector
  { inspectRepository :: FilePath -> effect (Either String Inspection)
  }

newtype Updater effect = Updater
  { pull :: FilePath -> effect (Either String ())
  }

newtype Observer effect = Observer
  { notify :: Event -> effect ()
  }

data Cast effect = Cast
  { surveyor :: Surveyor effect
  , inspector :: Inspector effect
  , updater :: Updater effect
  , observer :: Observer effect
  }
