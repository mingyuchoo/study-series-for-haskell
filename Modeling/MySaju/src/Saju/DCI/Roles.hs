{-# LANGUAGE RecordWildCards #-}

module Saju.DCI.Roles
  ( -- * Value Pipeline Roles (십성 기능 역할)
    InformationInterpreter (..)
  , DecisionMaker (..)
  , ValueProducer (..)
  , AssetMonetizer (..)
  , SystemGovernor (..)
  , InputActor (..)
  , SelfActor (..)
  , OutputActor (..)
  , ValueActor (..)
  , ControlActor (..)

    -- * Profile Diagnosis Roles (명식 진단 역할)
  , StrengthAssessor (..)
  , RiskAssessor (..)
  , ProfileAuditor (..)

    -- * Strategy & Investment Decision Roles (충돌 감지 및 규칙 중재 역할)
  , RiskStrategist (..)
  , OpportunityStrategist (..)
  , InvestmentArbiter (..)
  , RiskSentinel (..)
  , OpportunityScout (..)
  , RuleArbiter (..)

    -- * Wealth System Compounding Role (자산 복리 성장 역할)
  , WealthCompounder (..)
  , CompoundingEngine (..)
  )
where

import Saju.Domain.Core (Person (..), averageStrength)
import Saju.Domain.Decision
  ( InvestmentRule (..)
  , Opportunity (..)
  , RejectionReason (..)
  , Strategy (..)
  )
import Saju.Domain.Diagnosis (Risk (..), Strength (..))
import Saju.Domain.ValueFlow
  ( Asset (..)
  , Decision (..)
  , Governance (..)
  , Information (..)
  , Mind (..)
  , Product (..)
  )
import Saju.Domain.WealthSystem (GrowthPolicy (..), WealthSystem (..))

-- ============================================================================
-- 1. Value Pipeline Roles (인성 -> 비겁 -> 식상 -> 재성 -> 관성)
-- ============================================================================

-- | 인성(Input) 역할: 외부 정보를 이해력과 판단력으로 해석
class InformationInterpreter actor where
  interpretInformation :: actor -> Information -> Mind

-- | 비겁(Self) 역할: 내면의 이해와 판단을 의사결정으로 가공
class DecisionMaker actor where
  makeDecision :: actor -> Mind -> Decision

-- | 식상(Output) 역할: 의사결정을 생산성과 유용성을 지닌 산출물로 전환
class ValueProducer actor where
  produceValue :: actor -> Decision -> Product

-- | 재성(Value) 역할: 산출물을 현금흐름과 소유권(자산)으로 수익화
class AssetMonetizer actor where
  monetizeProduct :: actor -> Product -> Asset

-- | 관성(Control) 역할: 자산을 통제력, 책임성, 안정성 기반의 거버넌스로 관리
class SystemGovernor actor where
  governAsset :: actor -> Asset -> Governance

-- | Data(Person) -> Role(인성) 바인딩
newtype InputActor = InputActor
  { unInputActor :: Person
  }
  deriving (Show, Eq)

-- | Data(Person) -> Role(비겁) 바인딩
newtype SelfActor = SelfActor
  { unSelfActor :: Person
  }
  deriving (Show, Eq)

-- | Data(Person) -> Role(식상) 바인딩
newtype OutputActor = OutputActor
  { unOutputActor :: Person
  }
  deriving (Show, Eq)

-- | Data(Person) -> Role(재성) 바인딩
newtype ValueActor = ValueActor
  { unValueActor :: Person
  }
  deriving (Show, Eq)

-- | Data(Person) -> Role(관성) 바인딩
newtype ControlActor = ControlActor
  { unControlActor :: Person
  }
  deriving (Show, Eq)

instance InformationInterpreter InputActor where
  interpretInformation _ Information {..} =
    Mind
      { understanding = knowledge * 0.8 + insight * 0.2
      , judgment = knowledge * 0.4 + insight * 0.6
      }

instance DecisionMaker SelfActor where
  makeDecision (SelfActor Person {..}) Mind {..} =
    Decision
      { confidence = selfStrength * understanding
      , quality = judgment * inputStrength * selfStrength
      }

instance ValueProducer OutputActor where
  produceValue (OutputActor Person {..}) Decision {..} =
    Product
      { productivity = outputStrength * confidence
      , usefulness = outputStrength * quality
      }

instance AssetMonetizer ValueActor where
  monetizeProduct (ValueActor Person {..}) Product {..} =
    Asset
      { cashFlow = productivity * valueStrength
      , ownership = usefulness * valueStrength
      }

instance SystemGovernor ControlActor where
  governAsset (ControlActor Person {..}) Asset {..} =
    MkGovernance
      { controlCapacity = ownership * controlStrength
      , responsibility = cashFlow * controlStrength
      , stability = min controlStrength selfStrength
      }

-- ============================================================================
-- 2. Profile Diagnosis Roles (강점/위험 진단)
-- ============================================================================

-- | 명식의 강점을 평가하는 역할
class StrengthAssessor actor where
  assessStrengths :: actor -> [Strength]

-- | 명식의 불균형/위험을 평가하는 역할
class RiskAssessor actor where
  assessRisks :: actor -> [Risk]

-- | Data(Person) -> Role(명식 감사자) 바인딩
newtype ProfileAuditor = ProfileAuditor
  { unProfileAuditor :: Person
  }
  deriving (Show, Eq)

instance StrengthAssessor ProfileAuditor where
  assessStrengths (ProfileAuditor person@Person {..}) =
    concat
      [ [InformationInterpretation | inputStrength >= 0.65]
      , [Execution | outputStrength >= 0.65]
      , [Monetization | valueStrength >= 0.75]
      , [Governance | controlStrength >= 0.70]
      , [SystemThinking | averageStrength person >= 0.65]
      ]

instance RiskAssessor ProfileAuditor where
  assessRisks (ProfileAuditor Person {..}) =
    concat
      [ [OverExpansion | valueStrength > selfStrength + 0.2]
      , [ResourceOverload | valueStrength + controlStrength > selfStrength * 2.5]
      , [ControlPressure | controlStrength > selfStrength + 0.15]
      ]

-- ============================================================================
-- 3. Strategy Conflict & Investment Arbitration Roles (巳亥冲 & 규칙 기반 중재)
-- ============================================================================

-- | 리스크 관점 전략 판단 역할
class RiskStrategist actor where
  evaluateRiskStrategy :: actor -> Strategy

-- | 기회 관점 전략 판단 역할
class OpportunityStrategist actor where
  evaluateOpportunityStrategy :: actor -> Strategy

-- | 규칙 기반 투자 기회 심사 역할
class InvestmentArbiter actor where
  arbitrateOpportunity :: actor -> Opportunity -> Either [RejectionReason] Opportunity

-- | Data(Mind) -> Role(리스크 감시자) 바인딩
newtype RiskSentinel = RiskSentinel
  { unRiskSentinel :: Mind
  }
  deriving (Show, Eq)

-- | Data(Product) -> Role(기회 탐색자) 바인딩
newtype OpportunityScout = OpportunityScout
  { unOpportunityScout :: Product
  }
  deriving (Show, Eq)

-- | Data(InvestmentRule) -> Role(규칙 기반 중재자) 바인딩
newtype RuleArbiter = RuleArbiter
  { unRuleArbiter :: InvestmentRule
  }
  deriving (Show, Eq)

instance RiskStrategist RiskSentinel where
  evaluateRiskStrategy (RiskSentinel Mind {..})
    | judgment > 70 = Defensive
    | otherwise = Aggressive

instance OpportunityStrategist OpportunityScout where
  evaluateOpportunityStrategy (OpportunityScout Product {..})
    | productivity > 70 = Aggressive
    | otherwise = Defensive

instance InvestmentArbiter RuleArbiter where
  arbitrateOpportunity (RuleArbiter InvestmentRule {..}) opp@Opportunity {..} =
    case violations of
      [] -> Right opp
      rs -> Left rs
    where
      violations =
        concat
          [ [ExceedsMaxPositionSize positionSize maxPositionSize | positionSize > maxPositionSize]
          , [ExceedsRiskTolerance downsideRisk minMarginSafety | downsideRisk > minMarginSafety]
          ]

-- ============================================================================
-- 4. Wealth System Compounding Role (복리 자산 성장 엔진)
-- ============================================================================

-- | 자산 시스템을 1사이클 복리 성장시키는 역할
class WealthCompounder actor where
  compoundCycle :: actor -> WealthSystem -> WealthSystem

-- | Data(GrowthPolicy) -> Role(복리 성장 엔진) 바인딩
newtype CompoundingEngine = CompoundingEngine
  { unCompoundingEngine :: GrowthPolicy
  }
  deriving (Show, Eq)

instance WealthCompounder CompoundingEngine where
  compoundCycle (CompoundingEngine GrowthPolicy {..}) ws =
    ws
      { information = information ws * informationGrowthFactor
      , capability = capability ws + information ws * infoToCapabilityRate
      , production = production ws + capability ws * capabilityToProductionRate
      , assets = assets ws + production ws * productionToAssetsRate
      , governance = governance ws + assets ws * assetsToGovernanceRate
      }
