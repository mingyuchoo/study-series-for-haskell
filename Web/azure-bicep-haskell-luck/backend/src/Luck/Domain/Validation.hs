-- | 입력 검증 규칙 (순수). 결과는 'DomainError' 로 표현하며 HTTP를 모른다.
module Luck.Domain.Validation
    ( validateChecklistLabel
    , validateSignup
    ) where

import qualified Data.Text  as T
import           Luck.Error (DomainError (..))
import           Luck.Types (SignupReq (..))

-- | 회원가입 입력 검증. 통과하면 @Right ()@.
validateSignup :: SignupReq -> Either DomainError ()
validateSignup SignupReq {..}
  | T.null (T.strip srDisplayName) = Left (ValidationError "이름을 입력하세요.")
  | not (T.isInfixOf "@" srEmail) = Left (ValidationError "올바른 이메일을 입력하세요.")
  | T.length srPassword < 6 = Left (ValidationError "비밀번호는 6자 이상이어야 합니다.")
  | otherwise = Right ()

-- | 체크리스트 항목 라벨 검증 (1~200자).
validateChecklistLabel :: T.Text -> Either DomainError ()
validateChecklistLabel label
  | T.null l = Left (ValidationError "항목 내용을 입력하세요.")
  | T.length l > 200 = Left (ValidationError "항목 내용은 200자 이하여야 합니다.")
  | otherwise = Right ()
  where
    l = T.strip label
