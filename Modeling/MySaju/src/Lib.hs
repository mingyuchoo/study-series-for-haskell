{-# LANGUAGE RecordWildCards #-}

module Lib
  ( defaultOpportunity
  , defaultWorkflowRequest
  , renderWorkflowTrace
  , runMySajuApp
  )
where

import Saju.Context.SajuWorkflow
  ( SajuAnalysisReport (..)
  , WorkflowEvent
  , WorkflowRequest (..)
  , WorkflowState (..)
  , runFullSajuWorkflow
  , workflowStageOf
  )
import Saju.Context.WealthPipeline (GovernanceStage (..))
import Saju.Domain.Core (Person (..), mingyu)
import Saju.Domain.Decision
  ( ApprovedDecision (..)
  , DecisionOutcome (..)
  , Opportunity (..)
  , RejectedDecision (..)
  , defaultRules
  )
import Saju.Domain.Diagnosis (DiagnosisReport (..))
import Saju.Domain.ValueFlow (exampleInfo)
import Saju.Domain.WealthSystem
  ( GrowthSummary (..)
  , defaultGrowthPolicy
  , initialWealthSystem
  )
import Saju.StateMachine.Core (ExecutionTrace (..))

-- | 기본 시뮬레이션 투자 기회
defaultOpportunity :: Opportunity
defaultOpportunity =
  Opportunity
    { expectedReturn = 0.25
    , downsideRisk = 0.20
    , positionSize = 0.08
    }

-- | 기본 통합 워크플로우 실행 요청
defaultWorkflowRequest :: WorkflowRequest
defaultWorkflowRequest =
  WorkflowRequest
    { reqPerson = mingyu
    , reqInformation = exampleInfo
    , reqInvestmentRule = defaultRules
    , reqOpportunity = defaultOpportunity
    , reqInitialWealthSystem = initialWealthSystem
    , reqGrowthPolicy = defaultGrowthPolicy
    , reqProjectionCycles = 3
    }

-- | 순수 보고서 렌더링 함수
renderWorkflowTrace :: ExecutionTrace WorkflowState WorkflowEvent -> String
renderWorkflowTrace ExecutionTrace {..} =
  unlines $
    [ "=== MySaju ADT State Machine Report ==="
    , "State Transitions (" <> show (length stateHistory) <> " states):"
    ]
      ++ map (("  -> " <>) . show . workflowStageOf) stateHistory
      ++ ["Emitted Domain Events: " <> show (length eventLog)]
      ++ renderFinal finalState
  where
    renderFinal (WorkflowCompleted SajuAnalysisReport {..}) =
      [ ""
      , "[1] Person DayMaster: " <> show (dayMaster reportPerson)
      , "[2] Diagnosis Strengths: " <> show (diagnosedStrengths reportDiagnosis)
      , "    Diagnosis Risks:     " <> show (diagnosedRisks reportDiagnosis)
      , "    Balance Status:      " <> show (balanceStatus reportDiagnosis)
      , "[3] Value Pipeline:"
      , "    Mind:       " <> show (gsMind reportPipeline)
      , "    Decision:   " <> show (gsDecision reportPipeline)
      , "    Product:    " <> show (gsProduct reportPipeline)
      , "    Asset:      " <> show (gsAsset reportPipeline)
      , "    Governance: " <> show (gsGovernance reportPipeline)
      , "[4] Investment Decision: " <> renderDecision reportDecision
      , "[5] Wealth Growth (" <> show (totalCycles reportWealthGrowth) <> " cycles):"
      , "    Initial: " <> show (initialSystem reportWealthGrowth)
      , "    Final:   " <> show (finalSystem reportWealthGrowth)
      ]
    renderFinal other =
      ["Workflow stopped in non-terminal state: " <> show (workflowStageOf other)]

    renderDecision (DecisionApproved ApprovedDecision {..}) =
      "APPROVED | resolution="
        <> show approvedConflictResolution
        <> " | opportunity="
        <> show approvedOpportunity
    renderDecision (DecisionRejected RejectedDecision {..}) =
      "REJECTED | resolution="
        <> show rejectedConflictResolution
        <> " | reasons="
        <> show rejectionReasons

-- | 애플리케이션 진입점 (IO 경계)
runMySajuApp :: IO ()
runMySajuApp =
  case runFullSajuWorkflow defaultWorkflowRequest of
    Left failure ->
      putStrLn ("Workflow execution failed: " <> show failure)
    Right trace ->
      putStr (renderWorkflowTrace trace)
