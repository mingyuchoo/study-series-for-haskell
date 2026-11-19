{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE RecordWildCards #-}

module Saju.Context.ProfileDiagnosis
  ( -- * DCI Context (Role Bindings)
    DiagnosisContext (..)
  , mkDiagnosisContext

    -- * State Machine ADTs
  , DiagnosisStage (..)
  , DiagnosisState (..)
  , DiagnosisCommand (..)
  , DiagnosisEvent (..)
  , DiagnosisError (..)

    -- * State Machine & Pure Transitions
  , diagnosisStageOf
  , transitionDiagnosis
  , diagnosisMachine
  , standardDiagnosisCommands
  , runProfileDiagnosis
  )
where

import Saju.DCI.Roles
  ( ProfileAuditor (..)
  , RiskAssessor (..)
  , StrengthAssessor (..)
  )
import Saju.Domain.Core (Person)
import Saju.Domain.Diagnosis
  ( DiagnosisReport (..)
  , Risk
  , Strength
  , classifyBalance
  )
import Saju.StateMachine.Core
  ( ExecutionFailure
  , ExecutionTrace
  , StateMachine (..)
  , TransitionResult (..)
  , runCommands
  )

-- | DCI Context: Data(Person)를 명식 감사 역할(ProfileAuditor)에 바인딩
newtype DiagnosisContext = DiagnosisContext
  { auditorRole :: ProfileAuditor
  }
  deriving (Show, Eq)

-- | Role Binding 생성자
mkDiagnosisContext :: Person -> DiagnosisContext
mkDiagnosisContext person =
  DiagnosisContext
    { auditorRole = ProfileAuditor person
    }

-- | 진단 단계 식별자 ADT
data DiagnosisStage
  = StageDiagnosisPending
  | StageStrengthsEvaluated
  | StageDiagnosisCompleted
  deriving (Show, Eq, Ord, Enum, Bounded)

-- | 명식 진단 상태 ADT
data DiagnosisState
  = DiagnosisPending
  | StrengthsEvaluated [Strength]
  | DiagnosisCompleted DiagnosisReport
  deriving (Show, Eq)

-- | 명식 진단 전이 명령 ADT
data DiagnosisCommand
  = EvaluateStrengths
  | EvaluateRisks
  deriving (Show, Eq, Ord, Enum, Bounded)

-- | 명식 진단 도메인 이벤트 ADT
data DiagnosisEvent
  = StrengthsAssessed [Strength]
  | RisksAssessed [Risk]
  | ProfileDiagnosed DiagnosisReport
  deriving (Show, Eq)

-- | 명식 진단 전이 오류 ADT
data DiagnosisError = InvalidDiagnosisTransition
  { diagErrStage :: DiagnosisStage
  , diagErrCommand :: DiagnosisCommand
  }
  deriving (Show, Eq)

-- | 현재 진단 상태의 단계 태그 조회
diagnosisStageOf :: DiagnosisState -> DiagnosisStage
diagnosisStageOf DiagnosisPending = StageDiagnosisPending
diagnosisStageOf (StrengthsEvaluated _) = StageStrengthsEvaluated
diagnosisStageOf (DiagnosisCompleted _) = StageDiagnosisCompleted

-- | 순수 상태 전이 함수 (DCI Interaction)
transitionDiagnosis
  :: DiagnosisContext
  -> DiagnosisState
  -> DiagnosisCommand
  -> TransitionResult DiagnosisState DiagnosisEvent DiagnosisError
transitionDiagnosis DiagnosisContext {..} state cmd =
  case (state, cmd) of
    (DiagnosisPending, EvaluateStrengths) ->
      let foundStrengths = assessStrengths auditorRole
       in Transitioned
            (StrengthsEvaluated foundStrengths)
            [StrengthsAssessed foundStrengths]
    (StrengthsEvaluated foundStrengths, EvaluateRisks) ->
      let foundRisks = assessRisks auditorRole
          report =
            DiagnosisReport
              { diagnosedStrengths = foundStrengths
              , diagnosedRisks = foundRisks
              , balanceStatus = classifyBalance foundRisks
              }
       in Transitioned
            (DiagnosisCompleted report)
            [RisksAssessed foundRisks, ProfileDiagnosed report]
    _ ->
      TransitionRejected
        state
        InvalidDiagnosisTransition
          { diagErrStage = diagnosisStageOf state
          , diagErrCommand = cmd
          }

-- | 명식 진단 상태 머신 정의
diagnosisMachine
  :: StateMachine
       DiagnosisContext
       DiagnosisState
       DiagnosisCommand
       DiagnosisEvent
       DiagnosisError
diagnosisMachine =
  StateMachine
    { machineStep = transitionDiagnosis
    , isTerminal = \case
        DiagnosisCompleted _ -> True
        _ -> False
    }

-- | 표준 진단 명령 시퀀스
standardDiagnosisCommands :: [DiagnosisCommand]
standardDiagnosisCommands =
  [ EvaluateStrengths
  , EvaluateRisks
  ]

-- | Person에 대한 전체 강점/위험 진단 상태 머신을 순수 실행
runProfileDiagnosis
  :: Person
  -> Either
       (ExecutionFailure DiagnosisState DiagnosisCommand DiagnosisError)
       (ExecutionTrace DiagnosisState DiagnosisEvent)
runProfileDiagnosis person =
  runCommands
    diagnosisMachine
    (mkDiagnosisContext person)
    DiagnosisPending
    standardDiagnosisCommands
