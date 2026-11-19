module Saju.Domain.ValueFlow
  ( Information (..)
  , Mind (..)
  , Decision (..)
  , Product (..)
  , Asset (..)
  , Governance (..)
  , exampleInfo
  )
where

-- | 인성 단계 입력 값 객체: 외부 지식과 통찰
data Information = Information
  { knowledge :: Double
  , insight :: Double
  }
  deriving (Show, Eq)

-- | 인성 단계 산출 값 객체: 이해력과 판단력
data Mind = Mind
  { understanding :: Double
  , judgment :: Double
  }
  deriving (Show, Eq)

-- | 비겁 단계 산출 값 객체: 확신과 의사결정 품질
data Decision = Decision
  { confidence :: Double
  , quality :: Double
  }
  deriving (Show, Eq)

-- | 식상 단계 산출 값 객체: 생산성과 유용성
data Product = Product
  { productivity :: Double
  , usefulness :: Double
  }
  deriving (Show, Eq)

-- | 재성 단계 산출 값 객체: 현금흐름과 소유권
data Asset = Asset
  { cashFlow :: Double
  , ownership :: Double
  }
  deriving (Show, Eq)

-- | 관성 단계 산출 값 객체: 통제력, 책임성, 안정성
data Governance = MkGovernance
  { controlCapacity :: Double
  , responsibility :: Double
  , stability :: Double
  }
  deriving (Show, Eq)

-- | 예시 입력 정보
exampleInfo :: Information
exampleInfo =
  Information
    { knowledge = 100
    , insight = 120
    }
