module Lib
  ( runApp
  ) where

-- \| 애플리케이션 조립/부트스트랩 모듈
-- 도메인/애플리케이션/어댑터/인프라 계층을 연결하고, 서버를 기동한다.

import Adapters.PostgresRepository (PostgresRepo, initSchema, runWith)

import Application.UseCases
  ( createUserUC
  , deleteUserUC
  , getUserUC
  , listAllUsers
  , seedSampleData
  , updateUserUC
  )

import Control.Monad (void)

import Data.ByteString.Char8 qualified as BS
import Data.ByteString.Lazy.Char8 qualified as LBS

import Domain.Model (User (..))

import Infrastructure.Postgres (loadConnectInfoFromEnv, withConnection)

import Network.HTTP.Types (status200, status404)
import Network.Wai (Application, responseLBS)
import Network.Wai qualified as Wai
import Network.Wai.Handler.Warp (run)

import Text.Read (readMaybe)

-- | 간단한 라우팅: /health, /tests 두 엔드포인트 제공
mkApp :: (forall a. PostgresRepo a -> IO a) -> Application
mkApp runRepoAction req respond = case (requestMethod, pathInfo) of
  ("GET", []) -> respond $ ok "OK"
  ("GET", ["health"]) -> respond $ ok "healthy"
  -- 사용자 목록 조회: GET /users
  ("GET", ["users"]) -> do
    users <- runRepoAction (listAllUsers :: PostgresRepo [User])
    respond $ ok (LBS.pack (unlines (map render users)))
  -- 사용자 상세 조회: GET /users?id=1
  ("GET", ["users", "detail"]) -> do
    case lookupIntParam "id" of
      Nothing -> respond $ notFoundMsg "missing or invalid id"
      Just i -> do
        mu <- runRepoAction (getUserUC i :: PostgresRepo (Maybe User))
        case mu of
          Nothing -> respond $ notFoundMsg "user not found"
          Just u  -> respond $ ok (LBS.pack (render u))
  -- 생성: POST /users?id=1&name=Alice
  ("POST", ["users"]) ->
    case (lookupIntParam "id", lookupTextParam "name") of
      (Just i, Just n) -> do
        ok' <- runRepoAction (createUserUC (User i n) :: PostgresRepo Bool)
        respond $ ok (LBS.pack (if ok' then "created" else "skipped"))
      _ -> respond $ notFoundMsg "missing id or name"
  -- 수정: PUT /users?id=1&name=Alice2
  ("PUT", ["users"]) ->
    case (lookupIntParam "id", lookupTextParam "name") of
      (Just i, Just n) -> do
        ok' <- runRepoAction (updateUserUC (User i n) :: PostgresRepo Bool)
        respond $ ok (LBS.pack (if ok' then "updated" else "not-updated"))
      _ -> respond $ notFoundMsg "missing id or name"
  -- 삭제: DELETE /users?id=1
  ("DELETE", ["users"]) ->
    case lookupIntParam "id" of
      Just i -> do
        ok' <- runRepoAction (deleteUserUC i :: PostgresRepo Bool)
        respond $ ok (LBS.pack (if ok' then "deleted" else "not-deleted"))
      _ -> respond $ notFoundMsg "missing id"
  _ -> respond $ notFound
  where
    requestMethod = Wai.requestMethod req
    pathInfo = Wai.pathInfo req
    qs = Wai.queryString req
    ok msg = responseLBS status200 [("Content-Type", "text/plain; charset=utf-8")] msg
    notFound =
      responseLBS
        status404
        [("Content-Type", "text/plain")]
        (LBS.pack "not found")
    notFoundMsg m = responseLBS status404 [("Content-Type", "text/plain")] (LBS.pack m)
    render (User i n) = show i <> ": " <> n
    lookupParam k = lookup (BS.pack k) qs >>= id
    lookupTextParam k = fmap BS.unpack (lookupParam k)
    lookupIntParam k = lookupTextParam k >>= readMaybe

-- | 애플리케이션 실행
runApp :: IO ()
runApp = do
  -- 1) 환경변수로부터 DB 접속정보 로드
  ci <- loadConnectInfoFromEnv
  -- 2) 커넥션을 열고 스키마 초기화 및 시드 데이터 삽입
  withConnection ci $ \conn -> do
    initSchema conn
    -- 샘플 데이터 삽입 (id=1 upsert 성격)
    void $ runWith conn (seedSampleData :: PostgresRepo Bool)
  -- 3) HTTP 서버 기동
  putStrLn "[boot] 서버 시작: http://0.0.0.0:8000"
  withConnection ci $ \conn -> do
    let runRepoAction act = runWith conn act
    run 8000 (mkApp runRepoAction)
