{-# LANGUAGE RecordWildCards #-}

-- | 프로필 핸들러 (내 정보 조회/수정).
module Luck.Handler.Profile
    ( meH
    , updateMeH
    ) where

import           Luck.App             (AppM)
import           Luck.Handler.Util    (note404, runDB)
import           Luck.Repository.User (getUserById, updateProfile)
import           Luck.Types.Auth      (AuthUser (..))
import           Luck.Types.User      (ProfileUpdate (..), UserDTO)
import           Luck.Web.Dto         (userRowToDTO)

meH :: AuthUser -> AppM UserDTO
meH u = do
  mrow <- runDB (\p -> getUserById p (auId u))
  userRowToDTO <$> note404 "사용자를 찾을 수 없습니다." mrow

updateMeH :: AuthUser -> ProfileUpdate -> AppM UserDTO
updateMeH u ProfileUpdate {..} = do
  mrow <- runDB (\p -> updateProfile p (auId u) puDisplayName puBio puTimezone puThemeKey)
  userRowToDTO <$> note404 "사용자를 찾을 수 없습니다." mrow
