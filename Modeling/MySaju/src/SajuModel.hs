module SajuModel
  ( -- * Core Domain (DDD)
    Element (..)
  , FunctionRole (..)
  , TenGod (..)
  , Person (..)
  , mingyu

    -- * Value Pipeline Domain & Compatibility API
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

    -- * Profile Diagnosis Domain & Compatibility API
  , Strength (..)
  , strengths
  , Risk (..)
  , risks

    -- * Strategy Conflict & Investment Rule Domain & Compatibility API
  , Strategy (..)
  , riskStrategy
  , opportunityStrategy
  , Conflict (..)
  , resolve
  , InvestmentRule (..)
  , defaultRules
  , Opportunity (..)
  , acceptable

    -- * Wealth System Domain & Compatibility API
  , Wealth
  , WealthSystem (..)
  , growWealth
  )
where

import Data.Either (isRight)
import Saju.Context.ProfileDiagnosis
  ( DiagnosisState (..)
  , runProfileDiagnosis
  )
import Saju.Context.WealthGrowth
  ( GrowthProgress (..)
  , GrowthState (..)
  , runWealthGrowth
  )
import Saju.Context.WealthPipeline
  ( GovernanceStage (..)
  , PipelineState (..)
  , runWealthPipeline
  )
import Saju.DCI.Roles
  ( AssetMonetizer (..)
  , CompoundingEngine (..)
  , ControlActor (..)
  , DecisionMaker (..)
  , InformationInterpreter (..)
  , InputActor (..)
  , InvestmentArbiter (..)
  , OpportunityScout (..)
  , OpportunityStrategist (..)
  , OutputActor (..)
  , ProfileAuditor (..)
  , RiskAssessor (..)
  , RiskSentinel (..)
  , RiskStrategist (..)
  , RuleArbiter (..)
  , SelfActor (..)
  , StrengthAssessor (..)
  , SystemGovernor (..)
  , ValueActor (..)
  , ValueProducer (..)
  , WealthCompounder (..)
  )
import Saju.Domain.Core
  ( Element (..)
  , FunctionRole (..)
  , Person (..)
  , TenGod (..)
  , mingyu
  )
import Saju.Domain.Decision
  ( Conflict (..)
  , InvestmentRule (..)
  , Opportunity (..)
  , Strategy (..)
  , defaultRules
  , resolveStrategyConflict
  )
import Saju.Domain.Diagnosis
  ( DiagnosisReport (..)
  , Risk (..)
  , Strength (..)
  )
import Saju.Domain.ValueFlow
  ( Asset (..)
  , Decision (..)
  , Governance (..)
  , Information (..)
  , Mind (..)
  , Product (..)
  , exampleInfo
  )
import Saju.Domain.WealthSystem
  ( GrowthSummary (..)
  , Wealth
  , WealthSystem (..)
  , defaultGrowthPolicy
  )
import Saju.StateMachine.Core (ExecutionTrace (..))

-- ============================================================================
-- Facade: 기존 API를 DCI Role과 ADT 상태 머신에 위임
-- ============================================================================

input :: Information -> Mind
input = interpretInformation (InputActor mingyu)

process :: Person -> Mind -> Decision
process person = makeDecision (SelfActor person)

output :: Person -> Decision -> Product
output person = produceValue (OutputActor person)

monetize :: Person -> Product -> Asset
monetize person = monetizeProduct (ValueActor person)

govern :: Person -> Asset -> Governance
govern person = governAsset (ControlActor person)

wealthPipeline :: Person -> Information -> Governance
wealthPipeline person info =
  case runWealthPipeline person info of
    Right trace ->
      case finalState trace of
        GovernanceEstablished stage -> gsGovernance stage
        _ -> fallbackGovernance
    Left _ -> fallbackGovernance
  where
    fallbackGovernance =
      govern person
        . monetize person
        . output person
        . process person
        . input
        $ info

result :: Governance
result = wealthPipeline mingyu exampleInfo

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

strengths :: Person -> [Strength]
strengths person =
  case runProfileDiagnosis person of
    Right trace ->
      case finalState trace of
        DiagnosisCompleted report -> diagnosedStrengths report
        _ -> assessStrengths (ProfileAuditor person)
    Left _ -> assessStrengths (ProfileAuditor person)

risks :: Person -> [Risk]
risks person =
  case runProfileDiagnosis person of
    Right trace ->
      case finalState trace of
        DiagnosisCompleted report -> diagnosedRisks report
        _ -> assessRisks (ProfileAuditor person)
    Left _ -> assessRisks (ProfileAuditor person)

riskStrategy :: Mind -> Strategy
riskStrategy = evaluateRiskStrategy . RiskSentinel

opportunityStrategy :: Product -> Strategy
opportunityStrategy = evaluateOpportunityStrategy . OpportunityScout

resolve :: Strategy -> Strategy -> Conflict Strategy
resolve = resolveStrategyConflict

acceptable :: InvestmentRule -> Opportunity -> Bool
acceptable rule = isRight . arbitrateOpportunity (RuleArbiter rule)

growWealth :: WealthSystem -> WealthSystem
growWealth ws =
  case runWealthGrowth defaultGrowthPolicy ws 1 of
    Right trace ->
      case finalState trace of
        GrowthCompleted summary -> finalSystem summary
        GrowthCompounding progress -> gpCurrentSystem progress
        GrowthInitialized s -> s
    Left _ -> compoundCycle (CompoundingEngine defaultGrowthPolicy) ws
