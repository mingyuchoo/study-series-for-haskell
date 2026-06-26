-- | 계정(회원가입) 입력 검증 규칙 (순수). 결과는 'DomainError' 로 표현하며 HTTP를 모른다.
--   체크리스트 항목 검증은 'Luck.Domain.Checklist' 에 co-locate 되어 있다.
module Luck.Domain.Validation
    ( validateSignup
    ) where

import qualified Data.Text       as T
import           Luck.Error      (DomainError (..))
import           Luck.Types.Auth (SignupReq (..))

-- | 회원가입 입력 검증. 통과하면 @Right ()@.
validateSignup :: SignupReq -> Either DomainError ()
validateSignup SignupReq {..}
  | T.null (T.strip srDisplayName) = Left (ValidationError "이름을 입력하세요.")
  | not (T.isInfixOf "@" srEmail) = Left (ValidationError "올바른 이메일을 입력하세요.")
  | T.length srPassword < 6 = Left (ValidationError "비밀번호는 6자 이상이어야 합니다.")
  | otherwise = Right ()
