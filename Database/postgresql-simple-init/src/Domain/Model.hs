module Domain.Model
  ( User (..)
  ) where

-- | 도메인 엔터티
-- 데이터베이스/전송 계층과 무관하게 순수 타입으로 정의
-- (간단히 String 사용. 필요시 Text/Aeson으로 확장 가능)
data User = User
  { userId   :: Int
  , userName :: String
  }
  deriving (Eq, Show)
