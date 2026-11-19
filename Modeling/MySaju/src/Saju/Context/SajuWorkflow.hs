{-# LANGUAGE RecordWildCards #-}

module Saju.Context.SajuWorkflow
  ( -- * DCI Context (Composite Role Bindings)
    WorkflowContext (..)
  , mkWorkflowContext

    -- * Stage Payloads & Final Report
  , DiagnosedPayload (..)
  , PipelineCompletedPayload (..)
  , DecisionCompletedPayload (..)
  , SajuAnalysisReport (..)

    -- * State Machine ADTs
  , WorkflowStage (..)
  , SubMachineKind (..)
  , WorkflowState (..)
  , WorkflowCommand (..)
  , WorkflowEvent (..)
  , WorkflowError (..)

    -- * State Machine & Pure Transitions
  , workflowStageOf
  , transitionWorkflow
  , sajuWorkflowMachine
  , WorkflowRequest (..)
  , runFullSajuWorkflow
  )
where

import Saju.Context.InvestmentDecision
  ( DecisionError
  , DecisionEvent
  , DecisionState (..)
  , runInvestmentDecision
  )
import Saju.Context.ProfileDiagnosis
  ( DiagnosisContext
  , DiagnosisError
  , DiagnosisEvent
  , DiagnosisState (..)
  , diagnosisMachine
  , mkDiagnosisContext
  , standardDiagnosisCommands
  )
import Saju.Context.WealthGrowth
  ( GrowthError
  , GrowthEvent
  , GrowthState (..)
  , runWealthGrowth
  )
import Saju.Context.WealthPipeline
  ( GovernanceStage (..)
  , PipelineError
  , PipelineEvent
  , PipelineState (..)
  , WealthPipelineContext
  , mkWealthPipelineContext
  , standardPipelineCommands
  , wealthPipelineMachine
  )
import Saju.Domain.Core (Person)
import Saju.Domain.Decision
  ( DecisionOutcome (..)
  , InvestmentRule
  , Opportunity
  )
import Saju.Domain.Diagnosis (DiagnosisReport)
import Saju.Domain.ValueFlow (Information)
import Saju.Domain.WealthSystem (GrowthPolicy, GrowthSummary, WealthSystem)
import Saju.StateMachine.Core
  ( ExecutionFailure (..)
  , ExecutionTrace (..)
  , StateMachine (..)
  , TransitionResult (..)
  , runCommands
  )

-- | 최상위 DCI Context: Person을 진단 Context와 가치 파이프라인 Context에 바인딩
data WorkflowContext = WorkflowContext
  { wfDiagnosisContext :: DiagnosisContext
  , wfPipelineContext :: WealthPipelineContext
  }
  deriving (Show, Eq)

-- | Role Binding 생성자
mkWorkflowContext :: Person -> WorkflowContext
mkWorkflowContext person =
  WorkflowContext
    { wfDiagnosisContext = mkDiagnosisContext person
    , wfPipelineContext = mkWealthPipelineContext person
    }

-- | 단계별 누적 페이로드
data DiagnosedPayload = DiagnosedPayload
  { dpPerson :: Person
  , dpDiagnosis :: DiagnosisReport
  }
  deriving (Show, Eq)

data PipelineCompletedPayload = PipelineCompletedPayload
  { pcpPerson :: Person
  , pcpDiagnosis :: DiagnosisReport
  , pcpGovernanceStage :: GovernanceStage
  }
  deriving (Show, Eq)

data DecisionCompletedPayload = DecisionCompletedPayload
  { dcpPerson :: Person
  , dcpDiagnosis :: DiagnosisReport
  , dcpGovernanceStage :: GovernanceStage
  , dcpDecisionOutcome :: DecisionOutcome
  }
  deriving (Show, Eq)

-- | 전체 사주 작업 절차 완료 보고서
data SajuAnalysisReport = SajuAnalysisReport
  { reportPerson :: Person
  , reportDiagnosis :: DiagnosisReport
  , reportPipeline :: GovernanceStage
  , reportDecision :: DecisionOutcome
  , reportWealthGrowth :: GrowthSummary
  }
  deriving (Show, Eq)

-- | 워크플로우 단계 식별자 ADT
data WorkflowStage
  = StageWorkflowInitialized
  | StageProfileDiagnosed
  | StageValueFlowCompleted
  | StageDecisionEvaluated
  | StageWorkflowCompleted
  deriving (Show, Eq, Ord, Enum, Bounded)

-- | 하위 상태 머신 식별자 ADT
data SubMachineKind
  = SubDiagnosis
  | SubPipeline
  | SubDecision
  | SubGrowth
  deriving (Show, Eq, Ord, Enum, Bounded)

-- | 전체 사주 분석 절차 상태 ADT
data WorkflowState
  = WorkflowInitialized Person
  | ProfileDiagnosedState DiagnosedPayload
  | ValueFlowCompletedState PipelineCompletedPayload
  | DecisionEvaluatedState DecisionCompletedPayload
  | WorkflowCompleted SajuAnalysisReport
  deriving (Show, Eq)

-- | 전체 사주 분석 절차 전이 명령 ADT
data WorkflowCommand
  = RunProfileDiagnosis
  | RunValuePipeline Information
  | RunInvestmentDecision InvestmentRule Opportunity
  | RunWealthProjection WealthSystem GrowthPolicy Int
  deriving (Show, Eq)

-- | 전체 사주 분석 절차 도메인 이벤트 ADT (하위 머신 이벤트 통합)
data WorkflowEvent
  = DiagnosisEvt DiagnosisEvent
  | PipelineEvt PipelineEvent
  | DecisionEvt DecisionEvent
  | GrowthEvt GrowthEvent
  | WorkflowCompletedEvt SajuAnalysisReport
  deriving (Show, Eq)

-- | 전체 사주 분석 절차 오류 ADT
data WorkflowError
  = InvalidWorkflowTransition WorkflowStage WorkflowCommand
  | DiagnosisSubMachineFailed DiagnosisError
  | PipelineSubMachineFailed PipelineError
  | DecisionSubMachineFailed DecisionError
  | GrowthSubMachineFailed GrowthError
  | UnexpectedSubMachineTerminal SubMachineKind
  deriving (Show, Eq)

-- | 전체 워크플로우 실행 요청 DTO
data WorkflowRequest = WorkflowRequest
  { reqPerson :: Person
  , reqInformation :: Information
  , reqInvestmentRule :: InvestmentRule
  , reqOpportunity :: Opportunity
  , reqInitialWealthSystem :: WealthSystem
  , reqGrowthPolicy :: GrowthPolicy
  , reqProjectionCycles :: Int
  }
  deriving (Show, Eq)

-- | 현재 워크플로우 상태의 단계 태그 조회
workflowStageOf :: WorkflowState -> WorkflowStage
workflowStageOf (WorkflowInitialized _) = StageWorkflowInitialized
workflowStageOf (ProfileDiagnosedState _) = StageProfileDiagnosed
workflowStageOf (ValueFlowCompletedState _) = StageValueFlowCompleted
workflowStageOf (DecisionEvaluatedState _) = StageDecisionEvaluated
workflowStageOf (WorkflowCompleted _) = StageWorkflowCompleted

-- | 순수 상태 전이 함수: 각 하위 DCI Context 상태 머신을 조합하여 실행
transitionWorkflow
  :: WorkflowContext
  -> WorkflowState
  -> WorkflowCommand
  -> TransitionResult WorkflowState WorkflowEvent WorkflowError
transitionWorkflow WorkflowContext {..} state cmd =
  case (state, cmd) of
    (WorkflowInitialized person, RunProfileDiagnosis) ->
      case runCommands diagnosisMachine wfDiagnosisContext DiagnosisPending standardDiagnosisCommands of
        Left failure ->
          TransitionRejected state (DiagnosisSubMachineFailed (failureReason failure))
        Right trace ->
          case finalState trace of
            DiagnosisCompleted report ->
              let payload = DiagnosedPayload {dpPerson = person, dpDiagnosis = report}
               in Transitioned
                    (ProfileDiagnosedState payload)
                    (map DiagnosisEvt (eventLog trace))
            _ ->
              TransitionRejected state (UnexpectedSubMachineTerminal SubDiagnosis)
    (ProfileDiagnosedState DiagnosedPayload {..}, RunValuePipeline info) ->
      case runCommands
        wealthPipelineMachine
        wfPipelineContext
        (AwaitingInformation info)
        standardPipelineCommands of
        Left failure ->
          TransitionRejected state (PipelineSubMachineFailed (failureReason failure))
        Right trace ->
          case finalState trace of
            GovernanceEstablished govStage ->
              let payload =
                    PipelineCompletedPayload
                      { pcpPerson = dpPerson
                      , pcpDiagnosis = dpDiagnosis
                      , pcpGovernanceStage = govStage
                      }
               in Transitioned
                    (ValueFlowCompletedState payload)
                    (map PipelineEvt (eventLog trace))
            _ ->
              TransitionRejected state (UnexpectedSubMachineTerminal SubPipeline)
    (ValueFlowCompletedState PipelineCompletedPayload {..}, RunInvestmentDecision rule opp) ->
      case runInvestmentDecision
        (gsMind pcpGovernanceStage)
        (gsProduct pcpGovernanceStage)
        rule
        opp of
        Left failure ->
          TransitionRejected state (DecisionSubMachineFailed (failureReason failure))
        Right trace ->
          let mkNext outcome =
                let payload =
                      DecisionCompletedPayload
                        { dcpPerson = pcpPerson
                        , dcpDiagnosis = pcpDiagnosis
                        , dcpGovernanceStage = pcpGovernanceStage
                        , dcpDecisionOutcome = outcome
                        }
                 in Transitioned
                      (DecisionEvaluatedState payload)
                      (map DecisionEvt (eventLog trace))
           in case finalState trace of
                OpportunityApproved approved -> mkNext (DecisionApproved approved)
                OpportunityRejected rejected -> mkNext (DecisionRejected rejected)
                _ ->
                  TransitionRejected state (UnexpectedSubMachineTerminal SubDecision)
    ( DecisionEvaluatedState DecisionCompletedPayload {..}
      , RunWealthProjection initSys policy cycles
      ) ->
      case runWealthGrowth policy initSys cycles of
        Left failure ->
          TransitionRejected state (GrowthSubMachineFailed (failureReason failure))
        Right trace ->
          case finalState trace of
            GrowthCompleted summary ->
              let report =
                    SajuAnalysisReport
                      { reportPerson = dcpPerson
                      , reportDiagnosis = dcpDiagnosis
                      , reportPipeline = dcpGovernanceStage
                      , reportDecision = dcpDecisionOutcome
                      , reportWealthGrowth = summary
                      }
               in Transitioned
                    (WorkflowCompleted report)
                    (map GrowthEvt (eventLog trace) ++ [WorkflowCompletedEvt report])
            _ ->
              TransitionRejected state (UnexpectedSubMachineTerminal SubGrowth)
    _ ->
      TransitionRejected state (InvalidWorkflowTransition (workflowStageOf state) cmd)

-- | 통합 사주 분석 상태 머신 정의
sajuWorkflowMachine
  :: StateMachine
       WorkflowContext
       WorkflowState
       WorkflowCommand
       WorkflowEvent
       WorkflowError
sajuWorkflowMachine =
  StateMachine
    { machineStep = transitionWorkflow
    , isTerminal = \s -> case s of
        WorkflowCompleted _ -> True
        _ -> False
    }

-- | 전체 작업 절차(진단 -> 가치 파이프라인 -> 투자 의사결정 -> 복리 성장)를 순수 실행
runFullSajuWorkflow
  :: WorkflowRequest
  -> Either
       (ExecutionFailure WorkflowState WorkflowCommand WorkflowError)
       (ExecutionTrace WorkflowState WorkflowEvent)
runFullSajuWorkflow WorkflowRequest {..} =
  runCommands
    sajuWorkflowMachine
    (mkWorkflowContext reqPerson)
    (WorkflowInitialized reqPerson)
    [ RunProfileDiagnosis
    , RunValuePipeline reqInformation
    , RunInvestmentDecision reqInvestmentRule reqOpportunity
    , RunWealthProjection reqInitialWealthSystem reqGrowthPolicy reqProjectionCycles
    ]
