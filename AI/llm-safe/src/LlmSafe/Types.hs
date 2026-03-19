{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

-- | LLM 비결정성 관리의 핵심 타입 정의.
--
--   비결정적 결과('LlmResponse')와 검증된 결과('Verified')를
--   타입 수준에서 분리하여, 검증 없이는 결정적 함수에
--   비결정적 값을 전달할 수 없도록 강제한다.
module LlmSafe.Types
  ( -- * 비결정적 영역의 타입
    LlmResponse (..)
  , Confidence (..)

    -- * 검증된 결과 (스마트 생성자로만 생성 가능)
  , Verified
  , unVerified
  , mkVerified

    -- * 에러 타입
  , LlmError (..)

    -- * LLM 설정
  , LlmConfig (..)
  , defaultConfig
  ) where

-- | LLM의 원시 응답. 아직 검증되지 않은 비결정적 결과.
--
--   이 타입의 값은 'Verified'를 요구하는 결정적 함수에
--   직접 전달할 수 없다. 반드시 검증 관문을 통과해야 한다.
data LlmResponse a = LlmResponse
  { rawContent :: a
    -- ^ 원시 응답 내용
  , confidence :: Confidence
    -- ^ 모델이 보고한 신뢰도
  , modelId :: String
    -- ^ 어떤 모델이 생성했는가
  , promptHash :: String
    -- ^ 입력 프롬프트의 해시 (재현성 추적)
  }
  deriving stock (Show, Eq)

-- | 신뢰도 수준. LLM 출력의 불확실성을 명시적 값으로 표현.
data Confidence
  = Low
    -- ^ 자유 텍스트, 검증 어려움
  | Medium
    -- ^ 부분적으로 검증 가능
  | High
    -- ^ 구조화된 출력, 높은 일관성
  deriving stock (Show, Eq, Ord)

-- | 검증을 통과한 결과.
--
--   이 모듈은 'Verified' 데이터 생성자를 내보내지 않으므로,
--   외부에서는 'mkVerified'(모듈 내부용) 또는
--   'LlmSafe.Verify'의 검증 함수로만 생성할 수 있다.
--
--   이것이 타입이 강제하는 검증 관문이다.
newtype Verified a = Verified a
  deriving stock (Show, Eq)
  deriving newtype (Ord)

-- | 검증된 값을 꺼낸다.
unVerified :: Verified a -> a
unVerified (Verified a) = a

-- | 내부용 스마트 생성자. 'LlmSafe.Verify' 모듈에서만 사용한다.
mkVerified :: a -> Verified a
mkVerified = Verified

-- | LLM 처리 과정에서 발생할 수 있는 오류.
data LlmError
  = VerificationFailed String
    -- ^ 검증 실패 (술어 조건 불충족)
  | ConsensusNotReached String
    -- ^ 합의 도달 실패 (다수결 미달)
  | ParseError String
    -- ^ 구조화된 출력 파싱 실패
  | RetryExhausted Int
    -- ^ 재시도 횟수 초과
  | LowConfidence Confidence
    -- ^ 신뢰도가 요구 수준 미달
  deriving stock (Show, Eq)

-- | LLM 호출 설정.
data LlmConfig = LlmConfig
  { configModelId :: String
    -- ^ 사용할 모델 ID
  , configMaxRetries :: Int
    -- ^ 최대 재시도 횟수
  , configMinConfidence :: Confidence
    -- ^ 최소 요구 신뢰도
  }
  deriving stock (Show, Eq)

-- | 기본 설정.
defaultConfig :: LlmConfig
defaultConfig =
  LlmConfig
    { configModelId = "claude-sonnet-4-20250514"
    , configMaxRetries = 3
    , configMinConfidence = Medium
    }
