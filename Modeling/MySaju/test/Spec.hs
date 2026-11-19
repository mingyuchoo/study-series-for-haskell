{-# LANGUAGE RecordWildCards #-}

module Main (main) where

import Control.Monad (unless)
import Saju.Context.InvestmentDecision
  ( DecisionCommand (..)
  , DecisionError (..)
  , DecisionEvent (..)
  , DecisionStage (..)
  , DecisionState (..)
  , investmentDecisionMachine
  , mkInvestmentDecisionContext
  , runInvestmentDecision
  )
import Saju.Context.ProfileDiagnosis
  ( DiagnosisCommand (..)
  , DiagnosisError (..)
  , DiagnosisStage (..)
  , DiagnosisState (..)
  , diagnosisMachine
  , mkDiagnosisContext
  , runProfileDiagnosis
  )
import Saju.Context.SajuWorkflow
  ( SajuAnalysisReport (..)
  , WorkflowCommand (..)
  , WorkflowError (..)
  , WorkflowRequest (..)
  , WorkflowStage (..)
  , WorkflowState (..)
  , mkWorkflowContext
  , runFullSajuWorkflow
  , sajuWorkflowMachine
  , workflowStageOf
  )
import Saju.Context.WealthGrowth
  ( GrowthCommand (..)
  , GrowthError (..)
  , GrowthStage (..)
  , GrowthState (..)
  , mkWealthGrowthContext
  , runWealthGrowth
  , wealthGrowthMachine
  )
import Saju.Context.WealthPipeline
  ( GovernanceStage (..)
  , PipelineCommand (..)
  , PipelineError (..)
  , PipelineStage (..)
  , PipelineState (..)
  , mkWealthPipelineContext
  , runWealthPipeline
  , wealthPipelineMachine
  )
import Saju.Domain.Core
  ( functionRoleToTenGod
  , tenGodToFunctionRole
  )
import Saju.Domain.Decision
  ( ApprovedDecision (..)
  , DecisionOutcome (..)
  , RejectedDecision (..)
  , RejectionReason (..)
  )
import Saju.Domain.Diagnosis
  ( BalanceStatus (..)
  , DiagnosisReport (..)
  )
import Saju.Domain.WealthSystem
  ( GrowthSummary (..)
  , defaultGrowthPolicy
  , initialWealthSystem
  )
import Saju.StateMachine.Core
  ( ExecutionFailure (..)
  , ExecutionTrace (..)
  , StateMachine (..)
  , TransitionResult (..)
  , runUntilTerminal
  , step
  )
import SajuModel
import System.Exit (exitFailure)

assert :: String -> Bool -> IO ()
assert label condition =
  unless condition $ do
    putStrLn ("FAILED: " <> label)
    exitFailure

approxEq :: Double -> Double -> Bool
approxEq a b = abs (a - b) < 1e-9

main :: IO ()
main = do
  putStrLn "Running MySaju DDD + DCI + ADT State Machine tests..."

  -- 1. Core Domain & Compatibility Tests
  assert
    "TenGod <-> FunctionRole roundtrip"
    (all (\tg -> functionRoleToTenGod (tenGodToFunctionRole tg) == tg) [minBound .. maxBound])

  let expectedStrengths =
        [ InformationInterpretation
        , Execution
        , Monetization
        , Governance
        , SystemThinking
        ]
  assert "strengths mingyu matches" (strengths mingyu == expectedStrengths)

  let expectedRisks =
        [ OverExpansion
        , ResourceOverload
        , ControlPressure
        ]
  assert "risks mingyu matches" (risks mingyu == expectedRisks)

  let gov = wealthPipeline mingyu exampleInfo
  assert "wealthPipeline == lifeFlow" (gov == lifeFlow exampleInfo)
  assert "governance controlCapacity" (approxEq (controlCapacity gov) 20.61675)
  assert "governance responsibility" (approxEq (responsibility gov) 27.34875)
  assert "governance stability" (approxEq (stability gov) 0.55)

  -- 2. WealthPipeline State Machine Tests
  case runWealthPipeline mingyu exampleInfo of
    Left err -> assert ("WealthPipeline failed: " <> show err) False
    Right trace -> do
      assert "WealthPipeline visits 6 states" (length (stateHistory trace) == 6)
      assert "WealthPipeline emits 5 events" (length (eventLog trace) == 5)
      assert
        "WealthPipeline reaches terminal state"
        (isTerminal wealthPipelineMachine (finalState trace))
      case finalState trace of
        GovernanceEstablished GovernanceStage {..} -> do
          assert "Mind understanding" (approxEq (understanding gsMind) 104.0)
          assert "Mind judgment" (approxEq (judgment gsMind) 112.0)
          assert "Governance matches facade" (gsGovernance == gov)
        _ -> assert "Expected GovernanceEstablished" False

  let pipeCtx = mkWealthPipelineContext mingyu
  case step wealthPipelineMachine pipeCtx (AwaitingInformation exampleInfo) ProcessDecision of
    TransitionRejected _ (InvalidPipelineTransition StageAwaitingInformation ProcessDecision) ->
      pure ()
    other ->
      assert ("Expected InvalidPipelineTransition, got: " <> show other) False

  -- Test runUntilTerminal pure driver on WealthPipeline
  let nextPipeCmd s = case s of
        AwaitingInformation _ -> Just InterpretInformation
        MindFormed _ -> Just ProcessDecision
        DecisionMade _ -> Just ProduceOutput
        ProductCreated _ -> Just MonetizeProduct
        AssetMonetized _ -> Just EstablishGovernance
        GovernanceEstablished _ -> Nothing
  case runUntilTerminal
    10
    nextPipeCmd
    wealthPipelineMachine
    pipeCtx
    (AwaitingInformation exampleInfo) of
    Right trace ->
      assert
        "runUntilTerminal completes pipeline"
        (isTerminal wealthPipelineMachine (finalState trace) && length (eventLog trace) == 5)
    Left err ->
      assert ("runUntilTerminal failed: " <> show err) False

  -- 3. ProfileDiagnosis State Machine Tests
  case runProfileDiagnosis mingyu of
    Left err -> assert ("ProfileDiagnosis failed: " <> show err) False
    Right trace -> do
      assert "ProfileDiagnosis visits 3 states" (length (stateHistory trace) == 3)
      assert "ProfileDiagnosis emits 3 events" (length (eventLog trace) == 3)
      case finalState trace of
        DiagnosisCompleted DiagnosisReport {..} -> do
          assert "DiagnosisReport strengths" (diagnosedStrengths == expectedStrengths)
          assert "DiagnosisReport risks" (diagnosedRisks == expectedRisks)
          assert "DiagnosisReport balanceStatus" (balanceStatus == HighImbalance)
        _ -> assert "Expected DiagnosisCompleted" False

  let balancedPerson =
        Person
          { dayMaster = Earth
          , inputStrength = 0.60
          , selfStrength = 0.70
          , outputStrength = 0.60
          , valueStrength = 0.60
          , controlStrength = 0.60
          }
  case runProfileDiagnosis balancedPerson of
    Right trace ->
      case finalState trace of
        DiagnosisCompleted report ->
          assert "Balanced person has Balanced status" (balanceStatus report == Balanced)
        _ -> assert "Expected DiagnosisCompleted for balanced person" False
    Left err -> assert ("Balanced diagnosis failed: " <> show err) False

  case step diagnosisMachine (mkDiagnosisContext mingyu) DiagnosisPending EvaluateRisks of
    TransitionRejected _ (InvalidDiagnosisTransition StageDiagnosisPending EvaluateRisks) ->
      pure ()
    other ->
      assert ("Expected InvalidDiagnosisTransition, got: " <> show other) False

  -- 4. InvestmentDecision State Machine Tests (Agreement, Conflict, Approval, Rejection)
  let safeOpp =
        Opportunity
          { expectedReturn = 0.25
          , downsideRisk = 0.20
          , positionSize = 0.08
          }
      riskyOpp =
        Opportunity
          { expectedReturn = 0.50
          , downsideRisk = 0.45
          , positionSize = 0.25
          }
  assert "acceptable safeOpp" (acceptable defaultRules safeOpp)
  assert "not acceptable riskyOpp" (not (acceptable defaultRules riskyOpp))

  -- 4a. Consensus + Approved (exampleInfo -> judgment 112 Defensive, productivity 42.9 Defensive)
  let mindConsensus = input exampleInfo
      prodConsensus = output mingyu (process mingyu mindConsensus)
  case runInvestmentDecision mindConsensus prodConsensus defaultRules safeOpp of
    Right trace ->
      case finalState trace of
        OpportunityApproved ApprovedDecision {..} ->
          assert "Consensus Defensive approved" (approvedConflictResolution == Agreement Defensive)
        other -> assert ("Expected OpportunityApproved, got: " <> show other) False
    Left err -> assert ("Decision consensus failed: " <> show err) False

  -- 4b. 巳亥冲 Conflict + Approved (judgment 120 Defensive vs productivity 85 Aggressive)
  let conflictMind = Mind {understanding = 100, judgment = 120}
      conflictProd = Product {productivity = 85, usefulness = 60}
  case runInvestmentDecision conflictMind conflictProd defaultRules safeOpp of
    Right trace -> do
      assert
        "Conflict event emitted"
        (StrategyConflictDetected Defensive Aggressive `elem` eventLog trace)
      case finalState trace of
        OpportunityApproved ApprovedDecision {..} ->
          assert
            "Conflict resolved by rule and approved"
            (approvedConflictResolution == Conflict Defensive Aggressive)
        other -> assert ("Expected OpportunityApproved under conflict, got: " <> show other) False
    Left err -> assert ("Decision conflict approval failed: " <> show err) False

  -- 4c. 巳亥冲 Conflict + Rejected (both rules violated)
  case runInvestmentDecision conflictMind conflictProd defaultRules riskyOpp of
    Right trace ->
      case finalState trace of
        OpportunityRejected RejectedDecision {..} -> do
          assert
            "Conflict preserved on rejection"
            (rejectedConflictResolution == Conflict Defensive Aggressive)
          assert
            "Both rejection reasons recorded"
            ( rejectionReasons
                == [ ExceedsMaxPositionSize 0.25 0.10
                   , ExceedsRiskTolerance 0.45 0.30
                   ]
            )
        other -> assert ("Expected OpportunityRejected, got: " <> show other) False
    Left err -> assert ("Decision conflict rejection failed: " <> show err) False

  -- 4d. Illegal transition in InvestmentDecision
  let decCtx = mkInvestmentDecisionContext conflictMind conflictProd defaultRules
  case step
    investmentDecisionMachine
    decCtx
    AwaitingStrategySignals
    (EvaluateOpportunity safeOpp) of
    TransitionRejected _ (InvalidDecisionTransition StageAwaitingSignals _) ->
      pure ()
    other ->
      assert ("Expected InvalidDecisionTransition, got: " <> show other) False

  -- 5. WealthGrowth State Machine Tests
  case runWealthGrowth defaultGrowthPolicy initialWealthSystem 3 of
    Right trace -> do
      assert
        "WealthGrowth emits 3 CycleCompounded + 1 GrowthFinalized"
        (length (eventLog trace) == 4)
      case finalState trace of
        GrowthCompleted GrowthSummary {..} -> do
          let manual3 = growWealth (growWealth (growWealth initialWealthSystem))
          assert "3-cycle totalCycles == 3" (totalCycles == 3)
          assert "3-cycle snapshots count == 3" (length cycleSnapshots == 3)
          assert "3-cycle finalSystem matches iterated growWealth" (finalSystem == manual3)
        other -> assert ("Expected GrowthCompleted, got: " <> show other) False
    Left err -> assert ("WealthGrowth failed: " <> show err) False

  case runWealthGrowth defaultGrowthPolicy initialWealthSystem (-1) of
    Left ExecutionFailure {failureReason = InvalidCycleCount (-1)} -> pure ()
    other -> assert ("Expected InvalidCycleCount (-1), got: " <> show other) False

  let growthCtx = mkWealthGrowthContext defaultGrowthPolicy
  case step wealthGrowthMachine growthCtx (GrowthInitialized initialWealthSystem) FinalizeGrowth of
    Transitioned terminalState _ ->
      case step wealthGrowthMachine growthCtx terminalState AdvanceCycle of
        TransitionRejected _ (InvalidGrowthTransition StageGrowthCompleted AdvanceCycle) ->
          pure ()
        other -> assert ("Expected InvalidGrowthTransition, got: " <> show other) False
    other -> assert ("Expected zero-cycle GrowthCompleted, got: " <> show other) False

  -- 6. Unified SajuWorkflow End-to-End Orchestration State Machine Tests
  let req =
        WorkflowRequest
          { reqPerson = mingyu
          , reqInformation = exampleInfo
          , reqInvestmentRule = defaultRules
          , reqOpportunity = safeOpp
          , reqInitialWealthSystem = initialWealthSystem
          , reqGrowthPolicy = defaultGrowthPolicy
          , reqProjectionCycles = 3
          }
  case runFullSajuWorkflow req of
    Left err -> assert ("Full workflow failed: " <> show err) False
    Right trace -> do
      assert "Workflow visits 5 stages" (length (stateHistory trace) == 5)
      assert
        "Workflow stage sequence"
        ( map workflowStageOf (stateHistory trace)
            == [ StageWorkflowInitialized
               , StageProfileDiagnosed
               , StageValueFlowCompleted
               , StageDecisionEvaluated
               , StageWorkflowCompleted
               ]
        )
      assert
        "Workflow reaches terminal state"
        (isTerminal sajuWorkflowMachine (finalState trace))
      -- Events: 3 (diagnosis) + 5 (pipeline) + 3 (decision) + 4 (growth) + 1 (workflow completed) = 16
      assert "Workflow aggregates all 16 domain events" (length (eventLog trace) == 16)
      case finalState trace of
        WorkflowCompleted SajuAnalysisReport {..} -> do
          assert "Report person is mingyu" (reportPerson == mingyu)
          assert "Report pipeline governance matches" (gsGovernance reportPipeline == gov)
          case reportDecision of
            DecisionApproved _ -> pure ()
            DecisionRejected _ -> assert "Expected DecisionApproved in full workflow" False
          assert "Report wealth growth cycles == 3" (totalCycles reportWealthGrowth == 3)
        _ -> assert "Expected WorkflowCompleted" False

  -- Out-of-order workflow command must be rejected
  case step
    sajuWorkflowMachine
    (mkWorkflowContext mingyu)
    (WorkflowInitialized mingyu)
    (RunInvestmentDecision defaultRules safeOpp) of
    TransitionRejected _ (InvalidWorkflowTransition StageWorkflowInitialized _) ->
      pure ()
    other ->
      assert ("Expected InvalidWorkflowTransition, got: " <> show other) False

  putStrLn "All tests passed successfully!"
