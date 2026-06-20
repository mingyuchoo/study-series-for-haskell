{-# LANGUAGE OverloadedLabels  #-}
{-# LANGUAGE OverloadedStrings #-}

module GiGtkApp.App
  ( runApp
  ) where

import Data.GI.Base
import GI.Gtk qualified as Gtk

import GiGtkApp.Config
import GiGtkApp.UI.MainWindow

runApp :: IO ()
runApp = do
  app <-
    new
      Gtk.Application
      [#applicationId := appApplicationId defaultAppConfig]

  _ <-
    on app #activate $
      buildMainWindow app defaultAppConfig

  _ <- #run app Nothing
  return ()
