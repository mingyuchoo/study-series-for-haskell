module Saju.StateMachine.Core
  ( TransitionResult (..)
  , ExecutionTrace (..)
  , ExecutionFailure (..)
  , StateMachine (..)
  , step
  , runCommands
  , runUntilTerminal
  )
where

-- | 순수 상태 전이 결과 ADT (부분 필드 없음)
data TransitionResult s evt err
  = Transitioned s [evt]
  | TransitionRejected s err
  deriving (Show, Eq)

-- | 상태 머신 실행 이력 (최종 상태, 전체 상태 궤적, 도메인 이벤트 로그)
data ExecutionTrace s evt = ExecutionTrace
  { finalState :: s
  , stateHistory :: [s]
  , eventLog :: [evt]
  }
  deriving (Show, Eq)

-- | 상태 전이 실패 정보
data ExecutionFailure s cmd err = ExecutionFailure
  { failedAtStep :: Int
  , failedState :: s
  , failedCommand :: cmd
  , failureReason :: err
  }
  deriving (Show, Eq)

-- | DCI Context를 받아 순수하게 상태를 전이하는 제네릭 ADT 상태 머신
data StateMachine ctx s cmd evt err = StateMachine
  { machineStep :: ctx -> s -> cmd -> TransitionResult s evt err
  , isTerminal :: s -> Bool
  }

-- | 단일 명령에 대한 순수 상태 전이 실행
step
  :: StateMachine ctx s cmd evt err
  -> ctx
  -> s
  -> cmd
  -> TransitionResult s evt err
step = machineStep

-- | 명령 시퀀스를 순수하게 순차 실행하여 상태 궤적과 도메인 이벤트 로그를 생성
runCommands
  :: StateMachine ctx s cmd evt err
  -> ctx
  -> s
  -> [cmd]
  -> Either (ExecutionFailure s cmd err) (ExecutionTrace s evt)
runCommands sm ctx initial = go 1 initial [initial] []
  where
    go _ current revStates revEvents [] =
      Right
        ExecutionTrace
          { finalState = current
          , stateHistory = reverse revStates
          , eventLog = reverse revEvents
          }
    go idx current revStates revEvents (cmd : rest) =
      case machineStep sm ctx current cmd of
        Transitioned next evts ->
          go (idx + 1) next (next : revStates) (reverse evts ++ revEvents) rest
        TransitionRejected stuck err ->
          Left
            ExecutionFailure
              { failedAtStep = idx
              , failedState = stuck
              , failedCommand = cmd
              , failureReason = err
              }

-- | 종료 상태에 도달하거나 다음 명령이 없을 때까지 (최대 스텝 제한 내에서) 순수 자동 실행
runUntilTerminal
  :: Int
  -> (s -> Maybe cmd)
  -> StateMachine ctx s cmd evt err
  -> ctx
  -> s
  -> Either (ExecutionFailure s cmd err) (ExecutionTrace s evt)
runUntilTerminal maxSteps nextCmd sm ctx initial =
  go 1 maxSteps initial [initial] []
  where
    go idx remaining current revStates revEvents
      | isTerminal sm current || remaining <= 0 =
          Right
            ExecutionTrace
              { finalState = current
              , stateHistory = reverse revStates
              , eventLog = reverse revEvents
              }
      | otherwise =
          case nextCmd current of
            Nothing ->
              Right
                ExecutionTrace
                  { finalState = current
                  , stateHistory = reverse revStates
                  , eventLog = reverse revEvents
                  }
            Just cmd ->
              case machineStep sm ctx current cmd of
                Transitioned next evts ->
                  go
                    (idx + 1)
                    (remaining - 1)
                    next
                    (next : revStates)
                    (reverse evts ++ revEvents)
                TransitionRejected stuck err ->
                  Left
                    ExecutionFailure
                      { failedAtStep = idx
                      , failedState = stuck
                      , failedCommand = cmd
                      , failureReason = err
                      }
