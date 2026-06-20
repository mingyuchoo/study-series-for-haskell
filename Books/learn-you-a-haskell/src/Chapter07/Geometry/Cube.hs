module Chapter07.Geometry.Cube
  where

import Chapter07.Geometry.Cuboid qualified as Cuboid

volume :: Float -> Float
volume side = Cuboid.volume side side side

area :: Float -> Float
area side = Cuboid.area side side side
