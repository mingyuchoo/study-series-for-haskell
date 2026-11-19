module Saju.Domain.Diagnosis
  ( Strength (..)
  , Risk (..)
  , BalanceStatus (..)
  , DiagnosisReport (..)
  , classifyBalance
  )
where

-- | 명식의 강점 값 객체
data Strength
  = InformationInterpretation
  | Execution
  | Monetization
  | Governance
  | SystemThinking
  deriving (Show, Eq, Ord, Enum, Bounded)

-- | 명식의 불균형/위험 값 객체
data Risk
  = OverExpansion
  | ResourceOverload
  | DecisionConflict
  | ControlPressure
  deriving (Show, Eq, Ord, Enum, Bounded)

-- | 명식 균형 상태 분류
data BalanceStatus
  = Balanced
  | ModerateImbalance
  | HighImbalance
  deriving (Show, Eq, Ord)

-- | 진단 최종 보고서 값 객체
data DiagnosisReport = DiagnosisReport
  { diagnosedStrengths :: [Strength]
  , diagnosedRisks :: [Risk]
  , balanceStatus :: BalanceStatus
  }
  deriving (Show, Eq)

-- | 탐지된 위험 개수에 따른 균형 상태 분류
classifyBalance :: [Risk] -> BalanceStatus
classifyBalance [] = Balanced
classifyBalance [_] = ModerateImbalance
classifyBalance _ = HighImbalance
