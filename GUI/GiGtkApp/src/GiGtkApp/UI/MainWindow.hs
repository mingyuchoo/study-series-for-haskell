{-# LANGUAGE OverloadedLabels #-}

module GiGtkApp.UI.MainWindow
    ( buildMainWindow
    ) where

import           Data.GI.Base
import qualified GI.Gtk                  as Gtk

import           GiGtkApp.Config
import           GiGtkApp.UI.Handlers

buildMainWindow :: Gtk.Application -> AppConfig -> IO ()
buildMainWindow app config = do
    window <- new Gtk.ApplicationWindow
        [ #application := app
        , #title := appWindowTitle config
        , #defaultWidth := appWindowWidth config
        , #defaultHeight := appWindowHeight config
        ]

    button <- new Gtk.Button
        [ #label := appButtonLabel config ]

    _ <- on button #clicked onButtonClicked

    widget <- Gtk.toWidget button
    #setChild window (Just widget)
    #show window
