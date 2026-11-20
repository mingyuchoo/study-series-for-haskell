module GitPuller.Infrastructure.Encoding
  ( useLosslessUtf8
  ) where

import GHC.IO.Encoding
  ( mkTextEncoding
  , setFileSystemEncoding
  , setForeignEncoding
  , setLocaleEncoding
  )
import System.IO (hSetEncoding, stderr, stdout)

useLosslessUtf8 :: IO ()
useLosslessUtf8 = do
  encoding <- mkTextEncoding "UTF-8//ROUNDTRIP"
  setLocaleEncoding encoding
  setFileSystemEncoding encoding
  setForeignEncoding encoding
  hSetEncoding stdout encoding
  hSetEncoding stderr encoding
