{-# LANGUAGE RecordWildCards #-}

module Saju.Domain.Core
  ( Element (..)
  , FunctionRole (..)
  , TenGod (..)
  , Person (..)
  , tenGodToFunctionRole
  , functionRoleToTenGod
  , strengthForRole
  , averageStrength
  , mingyu
  )
where

-- | 오행 (Five Elements)
data Element
  = Wood
  | Fire
  | Earth
  | Metal
  | Water
  deriving (Show, Eq, Ord, Enum, Bounded)

-- | 십성의 기능적 역할 (Functional Role of Ten Gods)
data FunctionRole
  = Input -- 인성
  | Self -- 비겁
  | Output -- 식상
  | Value -- 재성
  | Control -- 관성
  deriving (Show, Eq, Ord, Enum, Bounded)

-- | 십성 (Ten Gods)
data TenGod
  = Resource -- 인성
  | Peer -- 비겁
  | Expression -- 식상
  | Wealth -- 재성
  | Authority -- 관성
  deriving (Show, Eq, Ord, Enum, Bounded)

-- | 명식의 핵심 상태 (Aggregate Root / Passive DCI Data)
data Person = Person
  { dayMaster :: Element
  , inputStrength :: Double
  , selfStrength :: Double
  , outputStrength :: Double
  , valueStrength :: Double
  , controlStrength :: Double
  }
  deriving (Show, Eq)

-- | 십성을 기능적 역할로 매핑
tenGodToFunctionRole :: TenGod -> FunctionRole
tenGodToFunctionRole Resource = Input
tenGodToFunctionRole Peer = Self
tenGodToFunctionRole Expression = Output
tenGodToFunctionRole Wealth = Value
tenGodToFunctionRole Authority = Control

-- | 기능적 역할을 십성으로 매핑
functionRoleToTenGod :: FunctionRole -> TenGod
functionRoleToTenGod Input = Resource
functionRoleToTenGod Self = Peer
functionRoleToTenGod Output = Expression
functionRoleToTenGod Value = Wealth
functionRoleToTenGod Control = Authority

-- | 기능 역할에 해당하는 명식 강도 조회
strengthForRole :: FunctionRole -> Person -> Double
strengthForRole Input = inputStrength
strengthForRole Self = selfStrength
strengthForRole Output = outputStrength
strengthForRole Value = valueStrength
strengthForRole Control = controlStrength

-- | 다섯 기능 강도의 산술 평균
averageStrength :: Person -> Double
averageStrength Person {..} =
  ( inputStrength
      + selfStrength
      + outputStrength
      + valueStrength
      + controlStrength
  )
    / 5

-- | 도메인 샘플 엔티티: 나 개인 (명규)
mingyu :: Person
mingyu =
  Person
    { dayMaster = Fire
    , inputStrength = 0.70
    , selfStrength = 0.55
    , outputStrength = 0.75
    , valueStrength = 0.85
    , controlStrength = 0.75
    }
