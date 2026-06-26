-- | 프로필 핸들러 (내 정보 조회/수정).
module Luck.Handler.Profile
  ( meH
  , updateMeH
  ) where

import Control.Monad.Except (throwError)
import Control.Monad.IO.Class (liftIO)
import Control.Monad.Reader (ask)
import Luck.App (AppEnv (..), AppM)
import Luck.Error (DomainError (..))
import Luck.Repository.User (UserRow, getUserById, updateProfile)
import Luck.Types
import Luck.Web.Dto (userRowToDTO)
import Luck.Web.Error (toServerError)

meH :: AuthUser -> AppM UserDTO
meH u = do
  env <- ask
  mrow <- liftIO (getUserById (envPool env) (auId u))
  toDtoOr404 mrow

updateMeH :: AuthUser -> ProfileUpdate -> AppM UserDTO
updateMeH u ProfileUpdate{..} = do
  env <- ask
  mrow <- liftIO (updateProfile (envPool env) (auId u) puDisplayName puBio puTimezone)
  toDtoOr404 mrow

-- | 사용자 행이 있으면 DTO로, 없으면 404.
toDtoOr404 :: Maybe UserRow -> AppM UserDTO
toDtoOr404 = maybe (throwError (toServerError notFound)) (pure . userRowToDTO)
  where
    notFound = NotFound "사용자를 찾을 수 없습니다."
