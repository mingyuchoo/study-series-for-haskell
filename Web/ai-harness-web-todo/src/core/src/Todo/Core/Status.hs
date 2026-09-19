{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE LambdaCase #-}

-- | 할 일 상태 기계입니다.
--
-- 허용된 전이의 Canonical Source는 이 모듈이며 도메인 설명은 @docs/domain/task.md@에 있습니다.
-- 저장 계층과 전송 계층은 상태 전이를 스스로 판단하지 않고 이 모듈을 통과시킵니다.
module Todo.Core.Status (
  TransitionError (..),
  allowedTransitions,
  canTransition,
  transition,
  isTerminal,
) where

import Todo.Core.Types (Status (..))

-- | 상태 전이가 거부된 이유입니다.
data TransitionError
  = -- | 현재 상태와 목표 상태가 같습니다. 호출자는 이를 멱등한 무변경으로 처리합니다.
    SameStatus Status
  | -- | 상태 기계가 허용하지 않는 전이입니다.
    ForbiddenTransition Status Status
  deriving stock (Eq, Show)

-- | 각 상태에서 이동할 수 있는 상태 목록입니다.
--
-- 'Archived'는 종료 상태이며 복원 경로를 제공하지 않습니다. 보관을 되돌리는 요구가
-- 생기면 새 전이를 임의로 추가하지 않고 ADR로 결정합니다.
allowedTransitions :: Status -> [Status]
allowedTransitions = \case
  Pending -> [InProgress, Done, Archived]
  InProgress -> [Pending, Done, Archived]
  Done -> [Pending, Archived]
  Archived -> []

-- | 나가는 전이가 없는 종료 상태인지 판단합니다.
isTerminal :: Status -> Bool
isTerminal = null . allowedTransitions

-- | 전이가 허용되는지만 확인합니다. 같은 상태는 전이가 아니므로 'False'입니다.
canTransition :: Status -> Status -> Bool
canTransition from to = to `elem` allowedTransitions from

-- | 전이를 적용하고 거부 사유를 명시적으로 반환합니다.
transition :: Status -> Status -> Either TransitionError Status
transition from to
  | from == to = Left (SameStatus from)
  | canTransition from to = Right to
  | otherwise = Left (ForbiddenTransition from to)
