{-# LANGUAGE RecordWildCards #-}

module Saju.Context.WealthGrowth
  ( -- * DCI Context (Role Bindings)
    WealthGrowthContext (..)
  , mkWealthGrowthContext

    -- * State Payloads
  , GrowthProgress (..)

    -- * State Machine ADTs
  , GrowthStage (..)
  , GrowthState (..)
  , GrowthCommand (..)
  , GrowthEvent (..)
  , GrowthError (..)

    -- * State Machine & Pure Transitions
  , growthStageOf
  , transitionGrowth
  , wealthGrowthMachine
  , growthCommandsForCycles
  , runWealthGrowth
  )
where

import Saju.DCI.Roles
  ( CompoundingEngine (..)
  , WealthCompounder (..)
  )
import Saju.Domain.WealthSystem
  ( CycleSnapshot (..)
  , GrowthPolicy
  , GrowthSummary (..)
  , WealthSystem
  )
import Saju.StateMachine.Core
  ( ExecutionFailure (..)
  , ExecutionTrace
  , StateMachine (..)
  , TransitionResult (..)
  , runCommands
  )

-- | DCI Context: Data(GrowthPolicy)를 복리 성장 엔진 역할(CompoundingEngine)에 바인딩
newtype WealthGrowthContext = WealthGrowthContext
  { compounderRole :: CompoundingEngine
  }
  deriving (Show, Eq)

-- | Role Binding 생성자
mkWealthGrowthContext :: GrowthPolicy -> WealthGrowthContext
mkWealthGrowthContext policy =
  WealthGrowthContext
    { compounderRole = CompoundingEngine policy
    }

-- | 복리 성장 진행 상태 페이로드
data GrowthProgress = GrowthProgress
  { gpInitialSystem :: WealthSystem
  , gpCurrentCycle :: Int
  , gpCurrentSystem :: WealthSystem
  , gpSnapshots :: [CycleSnapshot]
  }
  deriving (Show, Eq)

-- | 복리 성장 단계 식별자 ADT
data GrowthStage
  = StageGrowthInitialized
  | StageGrowthCompounding
  | StageGrowthCompleted
  deriving (Show, Eq, Ord, Enum, Bounded)

-- | 복리 자산 시스템 성장 상태 ADT
data GrowthState
  = GrowthInitialized WealthSystem
  | GrowthCompounding GrowthProgress
  | GrowthCompleted GrowthSummary
  deriving (Show, Eq)

-- | 복리 성장 전이 명령 ADT
data GrowthCommand
  = AdvanceCycle
  | FinalizeGrowth
  deriving (Show, Eq, Ord, Enum, Bounded)

-- | 복리 성장 도메인 이벤트 ADT
data GrowthEvent
  = CycleCompounded CycleSnapshot
  | GrowthFinalized GrowthSummary
  deriving (Show, Eq)

-- | 복리 성장 전이 오류 ADT (부분 필드 없음)
data GrowthError
  = InvalidGrowthTransition GrowthStage GrowthCommand
  | InvalidCycleCount Int
  deriving (Show, Eq)

-- | 현재 성장 상태의 단계 태그 조회
growthStageOf :: GrowthState -> GrowthStage
growthStageOf (GrowthInitialized _) = StageGrowthInitialized
growthStageOf (GrowthCompounding _) = StageGrowthCompounding
growthStageOf (GrowthCompleted _) = StageGrowthCompleted

-- | 순수 상태 전이 함수 (DCI Interaction)
transitionGrowth
  :: WealthGrowthContext
  -> GrowthState
  -> GrowthCommand
  -> TransitionResult GrowthState GrowthEvent GrowthError
transitionGrowth WealthGrowthContext {..} state cmd =
  case (state, cmd) of
    (GrowthInitialized initialSys, AdvanceCycle) ->
      let nextSys = compoundCycle compounderRole initialSys
          snap = CycleSnapshot {snapshotCycle = 1, snapshotSystem = nextSys}
          progress =
            GrowthProgress
              { gpInitialSystem = initialSys
              , gpCurrentCycle = 1
              , gpCurrentSystem = nextSys
              , gpSnapshots = [snap]
              }
       in Transitioned (GrowthCompounding progress) [CycleCompounded snap]
    (GrowthCompounding GrowthProgress {..}, AdvanceCycle) ->
      let nextCycle = gpCurrentCycle + 1
          nextSys = compoundCycle compounderRole gpCurrentSystem
          snap = CycleSnapshot {snapshotCycle = nextCycle, snapshotSystem = nextSys}
          progress =
            GrowthProgress
              { gpInitialSystem = gpInitialSystem
              , gpCurrentCycle = nextCycle
              , gpCurrentSystem = nextSys
              , gpSnapshots = gpSnapshots ++ [snap]
              }
       in Transitioned (GrowthCompounding progress) [CycleCompounded snap]
    (GrowthInitialized initialSys, FinalizeGrowth) ->
      let summary =
            GrowthSummary
              { totalCycles = 0
              , initialSystem = initialSys
              , finalSystem = initialSys
              , cycleSnapshots = []
              }
       in Transitioned (GrowthCompleted summary) [GrowthFinalized summary]
    (GrowthCompounding GrowthProgress {..}, FinalizeGrowth) ->
      let summary =
            GrowthSummary
              { totalCycles = gpCurrentCycle
              , initialSystem = gpInitialSystem
              , finalSystem = gpCurrentSystem
              , cycleSnapshots = gpSnapshots
              }
       in Transitioned (GrowthCompleted summary) [GrowthFinalized summary]
    (GrowthCompleted _, _) ->
      TransitionRejected state (InvalidGrowthTransition StageGrowthCompleted cmd)

-- | 복리 자산 성장 상태 머신 정의
wealthGrowthMachine
  :: StateMachine
       WealthGrowthContext
       GrowthState
       GrowthCommand
       GrowthEvent
       GrowthError
wealthGrowthMachine =
  StateMachine
    { machineStep = transitionGrowth
    , isTerminal = \s -> case s of
        GrowthCompleted _ -> True
        _ -> False
    }

-- | N 사이클 복리 성장 후 종료하는 명령 시퀀스 생성
growthCommandsForCycles :: Int -> Either GrowthError [GrowthCommand]
growthCommandsForCycles n
  | n < 0 = Left (InvalidCycleCount n)
  | otherwise = Right (replicate n AdvanceCycle ++ [FinalizeGrowth])

-- | 초기 WealthSystem과 GrowthPolicy로 N 사이클 복리 성장 상태 머신을 순수 실행
runWealthGrowth
  :: GrowthPolicy
  -> WealthSystem
  -> Int
  -> Either
       (ExecutionFailure GrowthState GrowthCommand GrowthError)
       (ExecutionTrace GrowthState GrowthEvent)
runWealthGrowth policy initialSys cycles =
  case growthCommandsForCycles cycles of
    Left err ->
      -- 음수 사이클 요청 시 명시적 오류 반환
      Left
        ExecutionFailure
          { failedAtStep = 0
          , failedState = GrowthInitialized initialSys
          , failedCommand = FinalizeGrowth
          , failureReason = err
          }
    Right cmds ->
      runCommands
        wealthGrowthMachine
        (mkWealthGrowthContext policy)
        (GrowthInitialized initialSys)
        cmds
