{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE RecordWildCards #-}

module Saju.Context.InvestmentDecision
  ( -- * DCI Context (Role Bindings)
    InvestmentDecisionContext (..)
  , mkInvestmentDecisionContext

    -- * State Machine ADTs
  , DecisionStage (..)
  , DecisionState (..)
  , DecisionCommand (..)
  , DecisionEvent (..)
  , DecisionError (..)

    -- * State Machine & Pure Transitions
  , decisionStageOf
  , transitionDecision
  , investmentDecisionMachine
  , standardDecisionCommands
  , runInvestmentDecision
  )
where

import Saju.DCI.Roles
  ( InvestmentArbiter (..)
  , OpportunityScout (..)
  , OpportunityStrategist (..)
  , RiskSentinel (..)
  , RiskStrategist (..)
  , RuleArbiter (..)
  )
import Saju.Domain.Decision
  ( ApprovedDecision (..)
  , Conflict (..)
  , InvestmentRule
  , Opportunity
  , RejectedDecision (..)
  , Strategy
  , StrategySignals (..)
  , resolveStrategyConflict
  )
import Saju.Domain.ValueFlow (Mind, Product)
import Saju.StateMachine.Core
  ( ExecutionFailure
  , ExecutionTrace
  , StateMachine (..)
  , TransitionResult (..)
  , runCommands
  )

-- | DCI Context: Mind, Product, InvestmentRule을 각 전략/중재 역할에 바인딩
data InvestmentDecisionContext = InvestmentDecisionContext
  { riskStrategistRole :: RiskSentinel
  , opportunityStrategistRole :: OpportunityScout
  , arbiterRole :: RuleArbiter
  }
  deriving (Show, Eq)

-- | Role Binding 생성자
mkInvestmentDecisionContext
  :: Mind
  -> Product
  -> InvestmentRule
  -> InvestmentDecisionContext
mkInvestmentDecisionContext mind prod rule =
  InvestmentDecisionContext
    { riskStrategistRole = RiskSentinel mind
    , opportunityStrategistRole = OpportunityScout prod
    , arbiterRole = RuleArbiter rule
    }

-- | 의사결정 단계 식별자 ADT
data DecisionStage
  = StageAwaitingSignals
  | StageSignalsCollected
  | StageConsensusReached
  | StageConflictDetected
  | StageOpportunityApproved
  | StageOpportunityRejected
  deriving (Show, Eq, Ord, Enum, Bounded)

-- | 巳亥冲 전략 충돌 해결 및 규칙 기반 투자 의사결정 상태 ADT
data DecisionState
  = AwaitingStrategySignals
  | SignalsCollected StrategySignals
  | ConsensusReached Strategy
  | ConflictDetected Strategy Strategy
  | OpportunityApproved ApprovedDecision
  | OpportunityRejected RejectedDecision
  deriving (Show, Eq)

-- | 투자 의사결정 전이 명령 ADT
data DecisionCommand
  = CollectSignals
  | ResolveConflict
  | EvaluateOpportunity Opportunity
  deriving (Show, Eq)

-- | 투자 의사결정 도메인 이벤트 ADT
data DecisionEvent
  = SignalsEvaluated StrategySignals
  | StrategyAgreed Strategy
  | StrategyConflictDetected Strategy Strategy
  | InvestmentApproved ApprovedDecision
  | InvestmentRejected RejectedDecision
  deriving (Show, Eq)

-- | 투자 의사결정 전이 오류 ADT
data DecisionError = InvalidDecisionTransition
  { decErrStage :: DecisionStage
  , decErrCommand :: DecisionCommand
  }
  deriving (Show, Eq)

-- | 현재 의사결정 상태의 단계 태그 조회
decisionStageOf :: DecisionState -> DecisionStage
decisionStageOf AwaitingStrategySignals = StageAwaitingSignals
decisionStageOf (SignalsCollected _) = StageSignalsCollected
decisionStageOf (ConsensusReached _) = StageConsensusReached
decisionStageOf (ConflictDetected _ _) = StageConflictDetected
decisionStageOf (OpportunityApproved _) = StageOpportunityApproved
decisionStageOf (OpportunityRejected _) = StageOpportunityRejected

-- | 규칙 중재자를 통해 투자 기회를 평가하는 순수 헬퍼
applyRuleArbitration
  :: RuleArbiter
  -> Conflict Strategy
  -> Opportunity
  -> TransitionResult DecisionState DecisionEvent DecisionError
applyRuleArbitration arbiter resolution opp =
  case arbitrateOpportunity arbiter opp of
    Right approvedOpp ->
      let approved =
            ApprovedDecision
              { approvedConflictResolution = resolution
              , approvedOpportunity = approvedOpp
              }
       in Transitioned (OpportunityApproved approved) [InvestmentApproved approved]
    Left reasons ->
      let rejected =
            RejectedDecision
              { rejectedConflictResolution = resolution
              , rejectedOpportunity = opp
              , rejectionReasons = reasons
              }
       in Transitioned (OpportunityRejected rejected) [InvestmentRejected rejected]

-- | 순수 상태 전이 함수 (DCI Interaction)
transitionDecision
  :: InvestmentDecisionContext
  -> DecisionState
  -> DecisionCommand
  -> TransitionResult DecisionState DecisionEvent DecisionError
transitionDecision InvestmentDecisionContext {..} state cmd =
  case (state, cmd) of
    (AwaitingStrategySignals, CollectSignals) ->
      let signals =
            StrategySignals
              { riskViewStrategy = evaluateRiskStrategy riskStrategistRole
              , opportunityViewStrategy = evaluateOpportunityStrategy opportunityStrategistRole
              }
       in Transitioned (SignalsCollected signals) [SignalsEvaluated signals]
    (SignalsCollected StrategySignals {..}, ResolveConflict) ->
      case resolveStrategyConflict riskViewStrategy opportunityViewStrategy of
        Agreement agreed ->
          Transitioned (ConsensusReached agreed) [StrategyAgreed agreed]
        Conflict leftStrat rightStrat ->
          Transitioned
            (ConflictDetected leftStrat rightStrat)
            [StrategyConflictDetected leftStrat rightStrat]
    (ConsensusReached agreed, EvaluateOpportunity opp) ->
      applyRuleArbitration arbiterRole (Agreement agreed) opp
    (ConflictDetected leftStrat rightStrat, EvaluateOpportunity opp) ->
      applyRuleArbitration arbiterRole (Conflict leftStrat rightStrat) opp
    _ ->
      TransitionRejected
        state
        InvalidDecisionTransition
          { decErrStage = decisionStageOf state
          , decErrCommand = cmd
          }

-- | 투자 의사결정 상태 머신 정의
investmentDecisionMachine
  :: StateMachine
       InvestmentDecisionContext
       DecisionState
       DecisionCommand
       DecisionEvent
       DecisionError
investmentDecisionMachine =
  StateMachine
    { machineStep = transitionDecision
    , isTerminal = \case
        OpportunityApproved _ -> True
        OpportunityRejected _ -> True
        _ -> False
    }

-- | 표준 의사결정 명령 시퀀스
standardDecisionCommands :: Opportunity -> [DecisionCommand]
standardDecisionCommands opp =
  [ CollectSignals
  , ResolveConflict
  , EvaluateOpportunity opp
  ]

-- | Mind, Product, InvestmentRule, Opportunity로 전체 의사결정 상태 머신을 순수 실행
runInvestmentDecision
  :: Mind
  -> Product
  -> InvestmentRule
  -> Opportunity
  -> Either
       (ExecutionFailure DecisionState DecisionCommand DecisionError)
       (ExecutionTrace DecisionState DecisionEvent)
runInvestmentDecision mind prod rule opp =
  runCommands
    investmentDecisionMachine
    (mkInvestmentDecisionContext mind prod rule)
    AwaitingStrategySignals
    (standardDecisionCommands opp)
