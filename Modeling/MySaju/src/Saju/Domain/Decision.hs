module Saju.Domain.Decision
  ( Strategy (..)
  , Conflict (..)
  , StrategySignals (..)
  , InvestmentRule (..)
  , Opportunity (..)
  , RejectionReason (..)
  , ApprovedDecision (..)
  , RejectedDecision (..)
  , DecisionOutcome (..)
  , defaultRules
  , resolveStrategyConflict
  )
where

-- | 투자/행동 전략 스탠스
data Strategy
  = Defensive
  | Aggressive
  deriving (Show, Eq, Ord)

-- | 巳亥冲(전략 충돌) 표현 ADT
data Conflict a
  = Agreement a
  | Conflict a a
  deriving (Show, Eq)

-- | 리스크 관점(Mind)과 기회 관점(Product)에서 수집된 전략 신호
data StrategySignals = StrategySignals
  { riskViewStrategy :: Strategy
  , opportunityViewStrategy :: Strategy
  }
  deriving (Show, Eq)

-- | 규칙 기반 의사결정 기준 값 객체
data InvestmentRule = InvestmentRule
  { maxPositionSize :: Double
  , maxLeverage :: Double
  , minMarginSafety :: Double
  }
  deriving (Show, Eq)

-- | 평가 대상 투자/실행 기회 값 객체
data Opportunity = Opportunity
  { expectedReturn :: Double
  , downsideRisk :: Double
  , positionSize :: Double
  }
  deriving (Show, Eq)

-- | 투자 규칙 위반 사유 ADT (부분 필드 방지를 위해 값 생성자 인자 사용)
data RejectionReason
  = ExceedsMaxPositionSize Double Double -- actual positionSize, maxPositionSize
  | ExceedsRiskTolerance Double Double -- actual downsideRisk, minMarginSafety
  deriving (Show, Eq)

-- | 승인된 투자 의사결정 결과
data ApprovedDecision = ApprovedDecision
  { approvedConflictResolution :: Conflict Strategy
  , approvedOpportunity :: Opportunity
  }
  deriving (Show, Eq)

-- | 거절된 투자 의사결정 결과
data RejectedDecision = RejectedDecision
  { rejectedConflictResolution :: Conflict Strategy
  , rejectedOpportunity :: Opportunity
  , rejectionReasons :: [RejectionReason]
  }
  deriving (Show, Eq)

-- | 투자 의사결정 최종 결과 ADT
data DecisionOutcome
  = DecisionApproved ApprovedDecision
  | DecisionRejected RejectedDecision
  deriving (Show, Eq)

-- | 기본 투자 규칙
defaultRules :: InvestmentRule
defaultRules =
  InvestmentRule
    { maxPositionSize = 0.10
    , maxLeverage = 1.50
    , minMarginSafety = 0.30
    }

-- | 두 전략 신호의 합의 또는 충돌 판별
resolveStrategyConflict :: Strategy -> Strategy -> Conflict Strategy
resolveStrategyConflict a b
  | a == b = Agreement a
  | otherwise = Conflict a b
