-- | 입력 검증 규칙 (순수). 결과는 'DomainError' 로 표현하며 HTTP를 모른다.
module Luck.Domain.Validation
  ( validateSignup
  ) where

import Data.Text qualified as T
import Luck.Error (DomainError (..))
import Luck.Types (SignupReq (..))

-- | 회원가입 입력 검증. 통과하면 @Right ()@.
validateSignup :: SignupReq -> Either DomainError ()
validateSignup SignupReq{..}
  | T.null (T.strip srDisplayName) = Left (ValidationError "이름을 입력하세요.")
  | not (T.isInfixOf "@" srEmail) = Left (ValidationError "올바른 이메일을 입력하세요.")
  | T.length srPassword < 6 = Left (ValidationError "비밀번호는 6자 이상이어야 합니다.")
  | otherwise = Right ()
