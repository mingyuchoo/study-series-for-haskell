{-# LANGUAGE RecordWildCards #-}

module Saju.Context.WealthPipeline
  ( -- * DCI Context (Role Bindings)
    WealthPipelineContext (..)
  , mkWealthPipelineContext

    -- * Stage Payloads
  , MindStage (..)
  , DecisionStage (..)
  , ProductStage (..)
  , AssetStage (..)
  , GovernanceStage (..)

    -- * State Machine ADTs
  , PipelineStage (..)
  , PipelineState (..)
  , PipelineCommand (..)
  , PipelineEvent (..)
  , PipelineError (..)

    -- * State Machine & Pure Transitions
  , pipelineStageOf
  , transitionPipeline
  , wealthPipelineMachine
  , standardPipelineCommands
  , runWealthPipeline
  )
where

import Saju.DCI.Roles
  ( AssetMonetizer (..)
  , ControlActor (..)
  , DecisionMaker (..)
  , InformationInterpreter (..)
  , InputActor (..)
  , OutputActor (..)
  , SelfActor (..)
  , SystemGovernor (..)
  , ValueActor (..)
  , ValueProducer (..)
  )
import Saju.Domain.Core (Person)
import Saju.Domain.ValueFlow
  ( Asset
  , Decision
  , Governance
  , Information
  , Mind
  , Product
  )
import Saju.StateMachine.Core
  ( ExecutionFailure
  , ExecutionTrace
  , StateMachine (..)
  , TransitionResult (..)
  , runCommands
  )

-- | DCI Context: Data(Person)를 십성 기반의 5개 협력 Role에 바인딩
data WealthPipelineContext = WealthPipelineContext
  { inputRole :: InputActor
  , selfRole :: SelfActor
  , outputRole :: OutputActor
  , valueRole :: ValueActor
  , controlRole :: ControlActor
  }
  deriving (Show, Eq)

-- | Role Binding 생성자
mkWealthPipelineContext :: Person -> WealthPipelineContext
mkWealthPipelineContext person =
  WealthPipelineContext
    { inputRole = InputActor person
    , selfRole = SelfActor person
    , outputRole = OutputActor person
    , valueRole = ValueActor person
    , controlRole = ControlActor person
    }

-- | 단계별 누적 아티팩트 페이로드
data MindStage = MindStage
  { msInfo :: Information
  , msMind :: Mind
  }
  deriving (Show, Eq)

data DecisionStage = DecisionStage
  { dsInfo :: Information
  , dsMind :: Mind
  , dsDecision :: Decision
  }
  deriving (Show, Eq)

data ProductStage = ProductStage
  { psInfo :: Information
  , psMind :: Mind
  , psDecision :: Decision
  , psProduct :: Product
  }
  deriving (Show, Eq)

data AssetStage = AssetStage
  { asInfo :: Information
  , asMind :: Mind
  , asDecision :: Decision
  , asProduct :: Product
  , asAsset :: Asset
  }
  deriving (Show, Eq)

data GovernanceStage = GovernanceStage
  { gsInfo :: Information
  , gsMind :: Mind
  , gsDecision :: Decision
  , gsProduct :: Product
  , gsAsset :: Asset
  , gsGovernance :: Governance
  }
  deriving (Show, Eq)

-- | 파이프라인 단계 식별자 ADT
data PipelineStage
  = StageAwaitingInformation
  | StageMindFormed
  | StageDecisionMade
  | StageProductCreated
  | StageAssetMonetized
  | StageGovernanceEstablished
  deriving (Show, Eq, Ord, Enum, Bounded)

-- | 가치 창출 파이프라인 상태 ADT
-- Information -> Mind -> Decision -> Product -> Asset -> Governance
data PipelineState
  = AwaitingInformation Information
  | MindFormed MindStage
  | DecisionMade DecisionStage
  | ProductCreated ProductStage
  | AssetMonetized AssetStage
  | GovernanceEstablished GovernanceStage
  deriving (Show, Eq)

-- | 파이프라인 전이 명령 ADT
data PipelineCommand
  = InterpretInformation -- 인성(Input): Information -> Mind
  | ProcessDecision -- 비겁(Self): Mind -> Decision
  | ProduceOutput -- 식상(Output): Decision -> Product
  | MonetizeProduct -- 재성(Value): Product -> Asset
  | EstablishGovernance -- 관성(Control): Asset -> Governance
  deriving (Show, Eq, Ord, Enum, Bounded)

-- | 파이프라인 도메인 이벤트 ADT
data PipelineEvent
  = InformationInterpreted Mind
  | DecisionProcessed Decision
  | OutputProduced Product
  | ProductMonetized Asset
  | GovernanceCompleted Governance
  deriving (Show, Eq)

-- | 파이프라인 전이 오류 ADT
data PipelineError = InvalidPipelineTransition
  { errCurrentStage :: PipelineStage
  , errAttemptedCommand :: PipelineCommand
  }
  deriving (Show, Eq)

-- | 현재 상태의 단계 태그 조회
pipelineStageOf :: PipelineState -> PipelineStage
pipelineStageOf (AwaitingInformation _) = StageAwaitingInformation
pipelineStageOf (MindFormed _) = StageMindFormed
pipelineStageOf (DecisionMade _) = StageDecisionMade
pipelineStageOf (ProductCreated _) = StageProductCreated
pipelineStageOf (AssetMonetized _) = StageAssetMonetized
pipelineStageOf (GovernanceEstablished _) = StageGovernanceEstablished

-- | 순수 상태 전이 함수 (DCI Interaction)
transitionPipeline
  :: WealthPipelineContext
  -> PipelineState
  -> PipelineCommand
  -> TransitionResult PipelineState PipelineEvent PipelineError
transitionPipeline WealthPipelineContext {..} state cmd =
  case (state, cmd) of
    (AwaitingInformation info, InterpretInformation) ->
      let mind = interpretInformation inputRole info
       in Transitioned
            (MindFormed MindStage {msInfo = info, msMind = mind})
            [InformationInterpreted mind]
    (MindFormed MindStage {..}, ProcessDecision) ->
      let decision = makeDecision selfRole msMind
       in Transitioned
            ( DecisionMade
                DecisionStage
                  { dsInfo = msInfo
                  , dsMind = msMind
                  , dsDecision = decision
                  }
            )
            [DecisionProcessed decision]
    (DecisionMade DecisionStage {..}, ProduceOutput) ->
      let prod = produceValue outputRole dsDecision
       in Transitioned
            ( ProductCreated
                ProductStage
                  { psInfo = dsInfo
                  , psMind = dsMind
                  , psDecision = dsDecision
                  , psProduct = prod
                  }
            )
            [OutputProduced prod]
    (ProductCreated ProductStage {..}, MonetizeProduct) ->
      let asset = monetizeProduct valueRole psProduct
       in Transitioned
            ( AssetMonetized
                AssetStage
                  { asInfo = psInfo
                  , asMind = psMind
                  , asDecision = psDecision
                  , asProduct = psProduct
                  , asAsset = asset
                  }
            )
            [ProductMonetized asset]
    (AssetMonetized AssetStage {..}, EstablishGovernance) ->
      let gov = governAsset controlRole asAsset
       in Transitioned
            ( GovernanceEstablished
                GovernanceStage
                  { gsInfo = asInfo
                  , gsMind = asMind
                  , gsDecision = asDecision
                  , gsProduct = asProduct
                  , gsAsset = asAsset
                  , gsGovernance = gov
                  }
            )
            [GovernanceCompleted gov]
    _ ->
      TransitionRejected
        state
        InvalidPipelineTransition
          { errCurrentStage = pipelineStageOf state
          , errAttemptedCommand = cmd
          }

-- | 가치 창출 파이프라인 상태 머신 정의
wealthPipelineMachine
  :: StateMachine
       WealthPipelineContext
       PipelineState
       PipelineCommand
       PipelineEvent
       PipelineError
wealthPipelineMachine =
  StateMachine
    { machineStep = transitionPipeline
    , isTerminal = \s -> case s of
        GovernanceEstablished _ -> True
        _ -> False
    }

-- | 표준 전체 파이프라인 명령 시퀀스
standardPipelineCommands :: [PipelineCommand]
standardPipelineCommands =
  [ InterpretInformation
  , ProcessDecision
  , ProduceOutput
  , MonetizeProduct
  , EstablishGovernance
  ]

-- | Person과 Information으로 전체 파이프라인 상태 머신을 순수 실행
runWealthPipeline
  :: Person
  -> Information
  -> Either
       (ExecutionFailure PipelineState PipelineCommand PipelineError)
       (ExecutionTrace PipelineState PipelineEvent)
runWealthPipeline person info =
  runCommands
    wealthPipelineMachine
    (mkWealthPipelineContext person)
    (AwaitingInformation info)
    standardPipelineCommands
