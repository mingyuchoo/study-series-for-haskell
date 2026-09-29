{-# LANGUAGE RecordWildCards #-}

module SajuModel
  ( Element (..)
  , FunctionRole (..)
  , TenGod (..)
  , Person (..)
  , mingyu
  , Information (..)
  , Mind (..)
  , input
  , Decision (..)
  , process
  , Product (..)
  , output
  , Asset (..)
  , monetize
  , Governance (..)
  , govern
  , wealthPipeline
  , exampleInfo
  , result
  , f
  , g
  , h
  , i
  , j
  , lifeFlow
  , Strength (..)
  , strengths
  , Risk (..)
  , risks
  , Strategy (..)
  , riskStrategy
  , opportunityStrategy
  , Conflict (..)
  , resolve
  , InvestmentRule (..)
  , defaultRules
  , Opportunity (..)
  , acceptable
  , Wealth
  , WealthSystem (..)
  , growWealth
  )
where

-- 오행
data Element
  = Wood
  | Fire
  | Earth
  | Metal
  | Water
  deriving (Show, Eq)

-- 십성의 기능적 해석
data FunctionRole
  = Input -- 인성
  | Self -- 비겁
  | Output -- 식상
  | Value -- 재성
  | Control -- 관성
  deriving (Show, Eq)

-- 십성
data TenGod
  = Resource -- 인성
  | Peer -- 비겁
  | Expression -- 식상
  | Wealth -- 재성
  | Authority -- 관성
  deriving (Show, Eq)

-- 명식의핵심 상태
data Person = Person
  { dayMaster :: Element
  , inputStrength :: Double
  , selfStrength :: Double
  , outputStrength :: Double
  , valueStrength :: Double
  , controlStrength :: Double
  }
  deriving (Show, Eq)

--
-- 나 개인
--

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

--
-- 인성 -> Input
--

data Information = Information
  { knowledge :: Double
  , insight :: Double
  }
  deriving (Show, Eq)

data Mind = Mind
  { understanding :: Double
  , judgment :: Double
  }
  deriving (Show, Eq)

input :: Information -> Mind
input Information {..} =
  Mind
    { understanding = knowledge * 0.8 + insight * 0.2
    , judgment = knowledge * 0.4 + insight * 0.6
    }

--
-- 비겁 == Processing
--

data Decision = Decision
  { confidence :: Double
  , quality :: Double
  }
  deriving (Show, Eq)

process :: Person -> Mind -> Decision
process Person {..} Mind {..} =
  Decision
    { confidence = selfStrength * understanding
    , quality = judgment * inputStrength * selfStrength
    }

--
-- 식상 -> Output
--

data Product = Product
  { productivity :: Double
  , usefulness :: Double
  }
  deriving (Show, Eq)

output :: Person -> Decision -> Product
output Person {..} Decision {..} =
  Product
    { productivity = outputStrength * confidence
    , usefulness = outputStrength * quality
    }

--
-- 재성 -> Value Capture
--

data Asset = Asset
  { cashFlow :: Double
  , ownership :: Double
  }
  deriving (Show, Eq)

monetize :: Person -> Product -> Asset
monetize Person {..} Product {..} =
  Asset
    { cashFlow = productivity * valueStrength
    , ownership = usefulness * valueStrength
    }

--
-- 관성 -> Control / Governance
--

data Governance = MkGovernance
  { controlCapacity :: Double
  , responsibility :: Double
  , stability :: Double
  }
  deriving (Show, Eq)

govern :: Person -> Asset -> Governance
govern Person {..} Asset {..} =
  MkGovernance
    { controlCapacity = ownership * controlStrength
    , responsibility = cashFlow * controlStrength
    , stability = min controlStrength selfStrength
    }

--
-- 전체 파이프라인
-- Information -> Mind -> Decision -> Product -> Asset -> Governance
--

wealthPipeline :: Person -> Information -> Governance
wealthPipeline person info =
  let
    mind = input info
    decision = process person mind
    prod = output person decision
    asset = monetize person prod
    governance = govern person asset
   in
    governance

--
-- 나에게 적용
--

exampleInfo :: Information
exampleInfo =
  Information
    { knowledge = 100
    , insight = 120
    }

result :: Governance
result = wealthPipeline mingyu exampleInfo

--
-- 요약 정리
--

f :: Information -> Mind
f = input

g :: Mind -> Decision
g = process mingyu

h :: Decision -> Product
h = output mingyu

i :: Product -> Asset
i = monetize mingyu

j :: Asset -> Governance
j = govern mingyu

lifeFlow :: Information -> Governance
lifeFlow = j . i . h . g . f

--
-- 나의 강점을 타입으로 모델링
--

data Strength
  = InformationInterpretation
  | Execution
  | Monetization
  | Governance
  | SystemThinking
  deriving (Show, Eq)

strengths :: Person -> [Strength]
strengths Person {..} =
  concat
    [ [InformationInterpretation | inputStrength >= 0.65]
    , [Execution | outputStrength >= 0.65]
    , [Monetization | valueStrength >= 0.75]
    , [Governance | controlStrength >= 0.70]
    , [SystemThinking | average >= 0.65]
    ]
  where
    average =
      ( inputStrength
          + selfStrength
          + outputStrength
          + valueStrength
          + controlStrength
      )
        / 5

-- strengths mingyu
-- [
--   InformationInterpretation,
--   Execution,
--   Monetization,
--   Governance,
--   SystemThinking
-- ]

--
-- 나의 약점은 Imbalance로 모델링
--

data Risk
  = OverExpansion
  | ResourceOverload
  | DecisionConflict
  | ControlPressure
  deriving (Show, Eq)

risks :: Person -> [Risk]
risks Person {..} =
  concat
    [ [OverExpansion | valueStrength > selfStrength + 0.2]
    , [ResourceOverload | valueStrength + controlStrength > selfStrength * 2.5]
    , [ControlPressure | controlStrength > selfStrength + 0.15]
    ]

-- risks mingyu
-- OverExpansion
-- ControlPressure

--
-- 巳亥冲을 Conflict로 모델링
--

data Strategy
  = Defensive
  | Aggressive
  deriving (Show, Eq)

riskStrategy :: Mind -> Strategy
riskStrategy Mind {..}
  | judgment > 70 = Defensive
  | otherwise = Aggressive

opportunityStrategy :: Product -> Strategy
opportunityStrategy Product {..}
  | productivity > 70 = Aggressive
  | otherwise = Defensive

data Conflict a
  = Agreement a
  | Conflict a a
  deriving (Show, Eq)

resolve :: Strategy -> Strategy -> Conflict Strategy
resolve a b
  | a == b = Agreement a
  | otherwise = Conflict a b

--
-- 해결책: Rule-Based Decision System
--

data InvestmentRule = InvestmentRule
  { maxPositionSize :: Double
  , maxLeverage :: Double
  , minMarginSafety :: Double
  }
  deriving (Show, Eq)

defaultRules :: InvestmentRule
defaultRules =
  InvestmentRule
    { maxPositionSize = 0.10
    , maxLeverage = 1.50
    , minMarginSafety = 0.30
    }

data Opportunity = Opportunity
  { expectedReturn :: Double
  , downsideRisk :: Double
  , positionSize :: Double
  }
  deriving (Show, Eq)

acceptable :: InvestmentRule -> Opportunity -> Bool
acceptable InvestmentRule {..} Opportunity {..} =
  positionSize <= maxPositionSize
    && downsideRisk <= minMarginSafety

--
-- 가장 중요한 개념: Wealth는 State가 아니다
--

type Wealth = Double

data WealthSystem = WealthSystem
  { information :: Double
  , capability :: Double
  , production :: Double
  , assets :: Double
  , governance :: Double
  }
  deriving (Show, Eq)

growWealth :: WealthSystem -> WealthSystem
growWealth ws =
  ws
    { information = information ws * 1.10
    , capability = capability ws + information ws * 0.05
    , production = production ws + capability ws * 0.08
    , assets = assets ws + production ws * 0.10
    , governance = governance ws + assets ws * 0.03
    }

-- 내 사주 구조
-- wealth = governance . monetize . produce . decide . learn
-- maximize (input -> capability -> output -> value -> control)
