-- | 이메일 발송 추상(포트)과 인증 코드.
--
-- 'PostStore'/'UserStore' 와 같은 record-of-functions 패턴이다. 구체 전송 수단은
-- 어댑터가 정한다 — 'logEmailSender' 는 실제 메일 대신 코드를 stderr 로 출력하는
-- 개발용이고, 운영용 provider 어댑터는 이 포트만 구현해 끼우면 된다.
module Blog.Email
  ( Code (..)
  , newCode
  , EmailSender (..)
  , logEmailSender
  ) where

import Crypto.Random (SystemDRG, getSystemDRG, randomBytesGenerate)
import Data.ByteString (ByteString)
import Data.ByteString qualified as BS
import Data.Text (Text)
import Data.Text qualified as T
import System.IO (hPutStrLn, stderr)
import Text.Printf (printf)

-- | 6자리 인증 코드.
newtype Code = Code { unCode :: Text }
  deriving stock (Eq, Show)

-- | 암호학적 난수로 6자리 코드(@000000@–@999999@)를 만든다.
newCode :: IO Code
newCode = do
  drg <- getSystemDRG
  let (bs, _) = randomBytesGenerate 4 drg :: (ByteString, SystemDRG)
      n = BS.foldl' (\acc b -> acc * 256 + fromIntegral b) (0 :: Integer) bs
  pure (Code (T.pack (printf "%06d" (n `mod` 1000000))))

-- | 이메일 발송 포트. 수신 주소와 코드를 받아 보낸다.
newtype EmailSender = EmailSender { sendCode :: Text -> Code -> IO () }

-- | 개발용 어댑터 — 실제 발송 대신 코드를 stderr 로 출력한다.
--   운영에서 provider 어댑터로 교체하기 전까지의 임시 구현.
logEmailSender :: EmailSender
logEmailSender = EmailSender $ \email (Code code) ->
  hPutStrLn stderr (T.unpack ("[email] " <> email <> " 인증코드: " <> code))
