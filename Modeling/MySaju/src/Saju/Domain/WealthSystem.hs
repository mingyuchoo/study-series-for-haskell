module Saju.Domain.WealthSystem
  ( Wealth
  , WealthSystem (..)
  , GrowthPolicy (..)
  , CycleSnapshot (..)
  , GrowthSummary (..)
  , defaultGrowthPolicy
  , initialWealthSystem
  )
where

-- | 부(Wealth)는 정적 스칼라 상태가 아닌 시스템 흐름의 결과
type Wealth = Double

-- | 복리 자산 시스템 상태 값 객체
data WealthSystem = WealthSystem
  { information :: Double
  , capability :: Double
  , production :: Double
  , assets :: Double
  , governance :: Double
  }
  deriving (Show, Eq)

-- | 시스템 복리 성장 계수 정책 값 객체
data GrowthPolicy = GrowthPolicy
  { informationGrowthFactor :: Double
  , infoToCapabilityRate :: Double
  , capabilityToProductionRate :: Double
  , productionToAssetsRate :: Double
  , assetsToGovernanceRate :: Double
  }
  deriving (Show, Eq)

-- | 특정 사이클에서의 자산 시스템 스냅샷
data CycleSnapshot = CycleSnapshot
  { snapshotCycle :: Int
  , snapshotSystem :: WealthSystem
  }
  deriving (Show, Eq)

-- | 복리 성장 절차 최종 요약
data GrowthSummary = GrowthSummary
  { totalCycles :: Int
  , initialSystem :: WealthSystem
  , finalSystem :: WealthSystem
  , cycleSnapshots :: [CycleSnapshot]
  }
  deriving (Show, Eq)

-- | 기본 복리 성장 정책 (기존 growWealth 계수)
defaultGrowthPolicy :: GrowthPolicy
defaultGrowthPolicy =
  GrowthPolicy
    { informationGrowthFactor = 1.10
    , infoToCapabilityRate = 0.05
    , capabilityToProductionRate = 0.08
    , productionToAssetsRate = 0.10
    , assetsToGovernanceRate = 0.03
    }

-- | 기본 시작 자산 시스템 (예시/시뮬레이션용)
initialWealthSystem :: WealthSystem
initialWealthSystem =
  WealthSystem
    { information = 100.0
    , capability = 50.0
    , production = 40.0
    , assets = 30.0
    , governance = 20.0
    }
