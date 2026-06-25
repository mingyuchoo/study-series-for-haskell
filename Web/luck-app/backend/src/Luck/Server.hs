-- | API 핸들러 구현.
module Luck.Server
  ( server
  ) where

import Control.Monad.Except (throwError)
import Control.Monad.IO.Class (liftIO)
import Control.Monad.Reader (ask)
import Data.Aeson (encode)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as T
import Data.Time (Day)
import Data.UUID.V4 (nextRandom)
import Luck.Api (API, ProtectedAPI, PublicAPI)
import Luck.App (AppEnv (..), AppM)
import Luck.Auth (hashPassword, issueToken, verifyPassword)
import Luck.Database
import Luck.Types
import Servant
import Servant.Auth.Server (AuthResult (..), throwAll)

-- | API 전체 서버.
server :: ServerT API AppM
server = publicServer :<|> protectedServer

-- | 공개 라우트 서버.
publicServer :: ServerT PublicAPI AppM
publicServer = signupH :<|> loginH :<|> logoutH :<|> catalogH

-- | 보호 라우트 서버. 인증되지 않으면 모든 엔드포인트에서 401.
protectedServer :: AuthResult AuthUser -> ServerT ProtectedAPI AppM
protectedServer (Authenticated u) =
  meH u
    :<|> updateMeH u
    :<|> recordsH u
    :<|> recordH u
    :<|> putRecordH u
protectedServer _ = throwAll (jsonErr err401 "인증이 필요합니다.")

-- 인증 ----------------------------------------------------------------------

signupH :: SignupReq -> AppM AuthResp
signupH req@SignupReq{..} = do
  case validSignup req of
    Just msg -> throwError (jsonErr err400 msg)
    Nothing -> do
      env <- ask
      mh <- liftIO (hashPassword srPassword)
      case mh of
        Nothing -> throwError (jsonErr err500 "비밀번호 처리 중 오류가 발생했습니다.")
        Just h -> do
          uid <- liftIO nextRandom
          res <- liftIO (insertUser (envPool env) uid srEmail h srDisplayName)
          case res of
            Left "email_taken" -> throwError (jsonErr err409 "이미 가입된 이메일입니다.")
            Left _ -> throwError (jsonErr err500 "가입 중 오류가 발생했습니다.")
            Right row -> mkAuthResp env row

loginH :: LoginReq -> AppM AuthResp
loginH LoginReq{..} = do
  env <- ask
  mrow <- liftIO (getUserByEmail (envPool env) lrEmail)
  case mrow of
    Nothing -> throwError invalid
    Just row ->
      if verifyPassword lrPassword (urPasswordHash row)
        then mkAuthResp env row
        else throwError invalid
  where
    invalid = jsonErr err401 "이메일 또는 비밀번호가 올바르지 않습니다."

logoutH :: AppM MessageResp
logoutH = pure (MessageResp "로그아웃되었습니다. 클라이언트에서 토큰을 삭제하세요.")

catalogH :: AppM [CatalogItem]
catalogH = pure catalog

-- 프로필 --------------------------------------------------------------------

meH :: AuthUser -> AppM UserDTO
meH u = do
  env <- ask
  mrow <- liftIO (getUserById (envPool env) (auId u))
  maybe (throwError (jsonErr err404 "사용자를 찾을 수 없습니다.")) (pure . userRowToDTO) mrow

updateMeH :: AuthUser -> ProfileUpdate -> AppM UserDTO
updateMeH u pu = do
  env <- ask
  mrow <- liftIO (updateProfile (envPool env) (auId u) pu)
  maybe (throwError (jsonErr err404 "사용자를 찾을 수 없습니다.")) (pure . userRowToDTO) mrow

-- 기록 ----------------------------------------------------------------------

recordsH :: AuthUser -> Maybe Day -> Maybe Day -> AppM [RecordDTO]
recordsH u mFrom mTo = do
  case (mFrom, mTo) of
    (Just from, Just to) -> do
      env <- ask
      rows <- liftIO (getRecordsBetween (envPool env) (auId u) from to)
      pure (map toDTO rows)
    _ -> throwError (jsonErr err400 "from, to 쿼리 파라미터가 필요합니다.")
  where
    toDTO (d, cs, note) = RecordDTO d (sanitize cs) note total

recordH :: AuthUser -> Day -> AppM RecordDTO
recordH u d = do
  env <- ask
  mrow <- liftIO (getRecord (envPool env) (auId u) d)
  pure $ case mrow of
    Just (rd, cs, note) -> RecordDTO rd (sanitize cs) note total
    Nothing -> RecordDTO d [] Nothing total

putRecordH :: AuthUser -> Day -> RecordUpdate -> AppM RecordDTO
putRecordH u d RecordUpdate{..} = do
  env <- ask
  let cleaned = sanitize ruCompleted
  (rd, cs, note) <- liftIO (upsertRecord (envPool env) (auId u) d cleaned ruNote)
  pure (RecordDTO rd (sanitize cs) note total)

-- 헬퍼 ----------------------------------------------------------------------

-- | 전체 일별 항목 수.
total :: Int
total = length catalog

-- | 알 수 없는 key 제거 + 중복 제거.
sanitize :: [Text] -> [Text]
sanitize xs = Set.toList (Set.intersection catalogKeys (Set.fromList xs))

-- | 토큰 + 사용자 DTO 응답을 만든다.
mkAuthResp :: AppEnv -> UserRow -> AppM AuthResp
mkAuthResp env row = do
  let au = AuthUser (urId row) (urEmail row)
  mtok <- liftIO (issueToken (envJwt env) au)
  case mtok of
    Nothing -> throwError (jsonErr err500 "토큰 발급에 실패했습니다.")
    Just tok -> pure (AuthResp tok (userRowToDTO row))

-- | 회원가입 입력 검증.
validSignup :: SignupReq -> Maybe Text
validSignup SignupReq{..}
  | T.null (T.strip srDisplayName) = Just "이름을 입력하세요."
  | not (T.isInfixOf "@" srEmail) = Just "올바른 이메일을 입력하세요."
  | T.length srPassword < 6 = Just "비밀번호는 6자 이상이어야 합니다."
  | otherwise = Nothing

-- | 에러 응답을 JSON 메시지 형태로 만든다.
jsonErr :: ServerError -> Text -> ServerError
jsonErr e msg =
  e
    { errBody = encode (MessageResp msg)
    , errHeaders = [("Content-Type", "application/json;charset=utf-8")]
    }
