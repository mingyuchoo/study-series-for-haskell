{-# LANGUAGE DerivingStrategies         #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

-- | LLM 비결정성 관리의 핵심 타입 정의.
--
--   비결정적 결과('LlmResponse')와 검증된 결과('Verified')를
--   타입 수준에서 분리하여, 검증 없이는 결정적 함수에
--   비결정적 값을 전달할 수 없도록 강제한다.
module LlmSafe.Types
    ( -- * 비결정적 영역의 타입
      Confidence (..)
    , LlmResponse (..)
      -- * 검증된 결과 (스마트 생성자로만 생성 가능)
    , Verified
    , mkVerified
    , unVerified
      -- * 에러 타입
    , LlmError (..)
    , renderLlmError
      -- * LLM 설정
    , LlmConfig (..)
    , defaultConfig
    ) where

import           System.Environment (lookupEnv)

-- | LLM의 원시 응답. 아직 검증되지 않은 비결정적 결과.
--
--   이 타입의 값은 'Verified'를 요구하는 결정적 함수에
--   직접 전달할 수 없다. 반드시 검증 관문을 통과해야 한다.
data LlmResponse a = LlmResponse { rawContent :: a
                                   -- ^ 원시 응답 내용
                                 , confidence :: Confidence
                                   -- ^ 모델이 보고한 신뢰도
                                 , modelId    :: String
                                   -- ^ 어떤 모델이 생성했는가
                                 , promptHash :: String
                                   -- ^ 입력 프롬프트의 해시 (재현성 추적)
                                 }
     deriving stock (Eq, Show)

-- | 신뢰도 수준. LLM 출력의 불확실성을 명시적 값으로 표현.
data Confidence = Low
                -- ^ 자유 텍스트, 검증 어려움
                | Medium
                -- ^ 부분적으로 검증 가능
                | High
                -- ^ 구조화된 출력, 높은 일관성
     deriving stock (Eq, Ord, Show)

-- | 검증을 통과한 결과.
--
--   이 모듈은 'Verified' 데이터 생성자를 내보내지 않으므로,
--   외부에서는 'mkVerified'(모듈 내부용) 또는
--   'LlmSafe.Verify'의 검증 함수로만 생성할 수 있다.
--
--   이것이 타입이 강제하는 검증 관문이다.
newtype Verified a = Verified a
     deriving stock (Eq, Show)
     deriving newtype (Ord)

-- | 검증된 값을 꺼낸다.
unVerified :: Verified a -> a
unVerified (Verified a) = a

-- | 내부용 스마트 생성자. 'LlmSafe.Verify' 모듈에서만 사용한다.
mkVerified :: a -> Verified a
mkVerified = Verified

-- | LLM 처리 과정에서 발생할 수 있는 오류.
data LlmError = VerificationFailed String
              -- ^ 검증 실패 (술어 조건 불충족)
              | ConsensusNotReached String
              -- ^ 합의 도달 실패 (다수결 미달)
              | ParseError String
              -- ^ 구조화된 출력 파싱 실패
              | RetryExhausted Int
              -- ^ 재시도 횟수 초과
              | LowConfidence Confidence
              -- ^ 신뢰도가 요구 수준 미달
     deriving stock (Eq, Show)

-- | 'LlmError'를 사람이 읽을 수 있는 한국어 문자열로 변환한다.
--
--   'show'를 사용하면 한국어가 유니코드 이스케이프로 깨지므로,
--   이 함수를 사용해 내부 메시지를 직접 꺼낸다.
renderLlmError :: LlmError -> String
renderLlmError (VerificationFailed msg)  = "검증 실패: " <> msg
renderLlmError (ConsensusNotReached msg) = "합의 실패: " <> msg
renderLlmError (ParseError msg)          = "파싱 오류: " <> msg
renderLlmError (RetryExhausted n)        = "재시도 초과: " <> show n <> "회"
renderLlmError (LowConfidence c)         = "신뢰도 부족: " <> show c

-- | LLM 호출 설정.
data LlmConfig = LlmConfig { configModelId        :: String
                             -- ^ 사용할 모델 배포 이름
                           , configMaxRetries     :: Int
                             -- ^ 최대 재시도 횟수
                           , configMinConfidence  :: Confidence
                             -- ^ 최소 요구 신뢰도
                           , configEndpoint       :: String
                             -- ^ Azure OpenAI 엔드포인트 URL
                           , configApiKey         :: String
                             -- ^ Azure OpenAI API 키
                           , configApiVersion     :: String
                             -- ^ Azure OpenAI API 버전
                           , configConsensusCount :: Int
                             -- ^ 합의 기반 파이프라인 호출 횟수
                           }
     deriving stock (Eq, Show)

-- | 기본 설정 (Azure OpenAI).
--
--   다음 환경 변수에서 값을 읽는다:
--
--   * @AZURE_OPENAI_ENDPOINT@    — Azure OpenAI 리소스 엔드포인트 URL
--   * @AZURE_OPENAI_API_KEY@     — API 인증 키
--   * @AZURE_OPENAI_DEPLOYMENT@  — 배포 모델 이름 (기본값: @gpt-5-mini@)
--   * @AZURE_OPENAI_API_VERSION@ — API 버전 (기본값: @2024-12-01-preview@)
--   * @LLM_CONSENSUS_COUNT@      — 합의 기반 호출 횟수 (기본값: @3@)
defaultConfig :: IO LlmConfig
defaultConfig = do
  endpoint       <- require "AZURE_OPENAI_ENDPOINT"
  apiKey         <- require "AZURE_OPENAI_API_KEY"
  model          <- getWithDefault "AZURE_OPENAI_DEPLOYMENT"  "gpt-5-mini"
  apiVersion     <- getWithDefault "AZURE_OPENAI_API_VERSION" "2024-12-01-preview"
  consensusCount <- getIntWithDefault "LLM_CONSENSUS_COUNT" 3
  pure LlmConfig
    { configModelId        = model
    , configMaxRetries     = 3
    , configMinConfidence  = Medium
    , configEndpoint       = endpoint
    , configApiKey         = apiKey
    , configApiVersion     = apiVersion
    , configConsensusCount = consensusCount
    }
 where
  require name = do
    mval <- lookupEnv name
    case mval of
      Just v  -> pure v
      Nothing -> ioError $ userError $ "환경 변수가 설정되지 않았습니다: " <> name
  getWithDefault name def = do
    mval <- lookupEnv name
    pure $ maybe def id mval
  getIntWithDefault name def = do
    mval <- lookupEnv name
    pure $ maybe def read mval
