module Hfm.Tui.Input (fromVty) where

import Hfm.Domain.Input
import qualified Graphics.Vty as V

fromVty :: V.Event -> Input
fromVty (V.EvResize w h) = Resize w h
fromVty (V.EvKey key modifiers) = case (convertKey key, traverse convertModifier modifiers) of
  (Just k, Just mods) -> KeyPress k mods
  _ -> Ignored
fromVty _ = Ignored

convertKey :: V.Key -> Maybe Key
convertKey key = case key of
  V.KChar c -> Just (KChar c)
  V.KFun n -> Just (KFun n)
  V.KUp -> Just KUp
  V.KDown -> Just KDown
  V.KLeft -> Just KLeft
  V.KRight -> Just KRight
  V.KPageUp -> Just KPageUp
  V.KPageDown -> Just KPageDown
  V.KHome -> Just KHome
  V.KEnd -> Just KEnd
  V.KEnter -> Just KEnter
  V.KEsc -> Just KEsc
  V.KBS -> Just KBS
  V.KDel -> Just KDel
  _ -> Nothing

convertModifier :: V.Modifier -> Maybe Modifier
convertModifier modifier = case modifier of
  V.MCtrl -> Just MCtrl
  V.MMeta -> Just MMeta
  V.MAlt -> Just MAlt
  V.MShift -> Just MShift
