module Lib
  ( someFunc
  ) where

import Graphics.UI.GLUT

someFunc :: IO ()
someFunc = do
  (progName, _) <- getArgsAndInitialize
  createWindow "OpenGL Example"
  displayCallback $= display
  mainLoop

display :: DisplayCallback
display = do
  clear [ColorBuffer]
  -- 삼각형 그리기
  renderPrimitive Triangles $ do
    color (Color3 1 0 0 :: Color3 GLfloat)
    vertex (Vertex3 0 1 0 :: Vertex3 GLfloat)
    color (Color3 0 1 0 :: Color3 GLfloat)
    vertex (Vertex3 (-1) (-1) 0 :: Vertex3 GLfloat)
    color (Color3 0 0 1 :: Color3 GLfloat)
    vertex (Vertex3 1 (-1) 0 :: Vertex3 GLfloat)
  flush
