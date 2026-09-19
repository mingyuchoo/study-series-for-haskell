{-# LANGUAGE OverloadedStrings #-}

-- | WAI 애플리케이션입니다.
--
-- 요청을 해석하고("Todo.Web.Route"), 유스케이스를 호출하고("Todo.Core.UseCase"),
-- 결과를 렌더링합니다("Todo.Web.View"). 이 모듈은 규칙을 구현하지 않습니다.
--
-- 라우팅을 Servant가 아니라 값 수준에서 처리하는 이유는 이 표면의 경로가 공개 계약이
-- 아니기 때문입니다. @api@의 라우트는 스크립트가 의존하므로 타입으로 고정할
-- 값어치가 있지만(@docs/decisions/ADR-0003-api-boundary.md@), 화면의 주소는 소비자가
-- 없습니다. 근거는 @src/web/docs/architecture.md@에 있습니다.
--
-- 저장소를 바꾸는 요청은 모두 출처 확인을 거칩니다("Todo.Web.Security"). 어떤 경로가
-- 그 대상인지는 'Todo.Web.Route.isWriteRoute' 하나가 정합니다.
module Todo.Web.Server (
  application,
) where

import Data.ByteString (ByteString)
import qualified Data.ByteString.Lazy as LazyByteString
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Encoding
import qualified Data.Text.Lazy.Encoding as LazyEncoding
import Data.Time (getCurrentTime, utctDay)
import Database.SQLite.Simple (Connection)
import Lucid (Html, renderText)
import Network.HTTP.Types (
  HeaderName,
  Status,
  hContentType,
  hLocation,
  parseQuery,
  status200,
  status303,
  status400,
  status403,
  status404,
  status405,
  status409,
  status413,
 )
import Network.Wai (
  Application,
  Request,
  RequestBodyLength (..),
  Response,
  pathInfo,
  queryString,
  requestBodyLength,
  requestHeaders,
  requestMethod,
  responseLBS,
  strictRequestBody,
 )
import Todo.Core.Filter (SortOrder (..))
import Todo.Core.Status (allowedTransitions)
import Todo.Core.Types (Todo (..), TodoId (..))
import Todo.Core.UseCase (
  UseCaseError (..),
  addTodo,
  changeStatus,
  deleteTodo,
  getTodo,
  listTodos,
  updateTodo,
 )
import Todo.Store.Sqlite (runSqlite)
import Todo.Web.Form (
  FormError,
  parseNewTodo,
  parsePatch,
  parseStatusChange,
  renderFormError,
 )
import Todo.Web.Route (
  ListQuery (..),
  Route (..),
  isWriteRoute,
  listFilter,
  parseRoute,
  renderRouteError,
 )
import Todo.Web.Security (checkFetchSite, renderFetchSiteRejection)
import Todo.Web.View (
  deleteConfirmSection,
  filterBar,
  messageSection,
  page,
  todoDetailSection,
  todoListSection,
 )

-- | 폼 본문의 상한입니다.
--
-- 이 표면의 폼은 제목과 태그 몇 개가 전부입니다. 상한을 두는 이유는 같은 기계의
-- 다른 프로세스가 큰 본문을 보내 메모리를 소모하는 것을 막기 위해서입니다.
maxBodyBytes :: Word
maxBodyBytes = 64 * 1024

-- | 연결 하나에 묶인 WAI 애플리케이션입니다.
application :: Connection -> Application
application conn request respond =
  case parseRoute (decodeUtf8Lenient (requestMethod request)) (pathInfo request) (queryText request) of
    Left err ->
      respond (messageResponse status400 "요청을 이해하지 못했습니다" (renderRouteError err))
    Right route
      | isWriteRoute route -> guardOrigin route
      | otherwise -> handle conn request route >>= respond
 where
  guardOrigin route =
    case checkFetchSite (headerText "sec-fetch-site" request) of
      Left rejection ->
        respond
          ( messageResponse
              status403
              "변경하지 않았습니다"
              (renderFetchSiteRejection rejection)
          )
      Right () -> handle conn request route >>= respond

-- | 해석된 요청을 처리합니다.
handle :: Connection -> Request -> Route -> IO Response
handle conn request route = case route of
  ListRoute query -> do
    todos <- runSqlite conn (listTodos (listFilter query) ByDueDate)
    pure
      ( htmlResponse
          status200
          "할 일"
          (todoListSection (filterBar (queryStatus query) (queryShowAll query)) todos)
      )
  DetailRoute rawId -> withTodo rawId (pure . detailResponse)
  DeleteFormRoute rawId ->
    withTodo rawId (pure . htmlResponse status200 "삭제 확인" . deleteConfirmSection)
  CreateRoute -> withForm $ \fields -> do
    now <- getCurrentTime
    case parseNewTodo now (utctDay now) fields of
      Left err -> pure (formErrorResponse err)
      Right newTodo -> do
        todo <- runSqlite conn (addTodo newTodo)
        pure (redirectTo (detailPath (todoId todo)))
  EditRoute rawId -> withForm $ \fields -> do
    now <- getCurrentTime
    case parsePatch fields of
      Left err -> pure (formErrorResponse err)
      Right patch -> do
        result <- runSqlite conn (updateTodo now patch (TodoId rawId))
        pure (afterChange rawId (fmap (const ()) result))
  StatusRoute rawId -> withForm $ \fields -> do
    now <- getCurrentTime
    case parseStatusChange fields of
      Left err -> pure (formErrorResponse err)
      Right target -> do
        result <- runSqlite conn (changeStatus now target (TodoId rawId))
        pure (afterChange rawId (fmap (const ()) result))
  DeleteRoute rawId -> withForm $ \_ -> do
    result <- runSqlite conn (deleteTodo (TodoId rawId))
    pure $ case result of
      Left err -> useCaseResponse err
      -- 삭제한 뒤에는 돌아갈 상세 화면이 없으므로 목록으로 보냅니다.
      Right () -> redirectTo "/"
  MethodMismatch ->
    pure (messageResponse status405 "허용되지 않은 요청" "그 방식으로는 받지 않습니다.")
  UnknownRoute ->
    pure (messageResponse status404 "할 일" "그런 화면이 없습니다.")
 where
  withTodo rawId continue = do
    result <- runSqlite conn (getTodo (TodoId rawId))
    either (pure . useCaseResponse) continue result

  -- 변경에 성공하면 상세 화면으로 다시 보냅니다. 새로 고침이 같은 변경을 다시
  -- 실행하지 않게 하기 위한 것입니다.
  afterChange rawId result = case result of
    Left err -> useCaseResponse err
    Right () -> redirectTo (detailPath (TodoId rawId))

  withForm continue = do
    body <- readFormBody request
    either pure continue body

  detailResponse todo =
    htmlResponse
      status200
      "할 일"
      (todoDetailSection (allowedTransitions (todoStatus todo)) todo)

-- | 폼 본문을 읽어 필드 쌍으로 옮깁니다. 상한을 넘으면 읽지 않고 거부합니다.
readFormBody :: Request -> IO (Either Response [(Text, Text)])
readFormBody request = case requestBodyLength request of
  KnownLength len
    | len > fromIntegral maxBodyBytes ->
        pure (Left (messageResponse status413 "받지 않았습니다" "보낸 내용이 너무 큽니다."))
  _ -> do
    body <- strictRequestBody request
    let strict = LazyByteString.toStrict (LazyByteString.take (fromIntegral maxBodyBytes + 1) body)
    if fromIntegral (LazyByteString.length body) > maxBodyBytes
      then pure (Left (messageResponse status413 "받지 않았습니다" "보낸 내용이 너무 큽니다."))
      else
        pure
          ( Right
              [ (decodeUtf8Lenient key, maybe "" decodeUtf8Lenient value)
              | (key, value) <- parseQuery strict
              ]
          )

-- 응답 만들기 ----------------------------------------------------------------

useCaseResponse :: UseCaseError -> Response
useCaseResponse err = case err of
  TodoNotFound _ -> messageResponse status404 "할 일" "그런 할 일이 없습니다."
  InvalidTransition _ _ ->
    messageResponse status409 "바꾸지 않았습니다" "지금 상태에서는 할 수 없는 변경입니다."

formErrorResponse :: FormError -> Response
formErrorResponse err = messageResponse status400 "저장하지 않았습니다" (renderFormError err)

redirectTo :: ByteString -> Response
redirectTo location = responseLBS status303 [(hLocation, location)] mempty

detailPath :: TodoId -> ByteString
detailPath (TodoId n) = "/todos/" <> Encoding.encodeUtf8 (tshow n)

messageResponse :: Status -> Text -> Text -> Response
messageResponse status title message =
  htmlResponse status title (messageSection message)

htmlResponse :: Status -> Text -> Html () -> Response
htmlResponse status title body =
  responseLBS
    status
    [(hContentType, "text/html; charset=utf-8")]
    (LazyEncoding.encodeUtf8 (renderText (page title body)))

-- 요청 읽기 ------------------------------------------------------------------

-- | 질의 문자열을 텍스트 쌍으로 옮깁니다.
--
-- 유효하지 않은 UTF-8은 대체 문자로 바꿉니다. 해석에 실패했다고 요청 전체를 거부하면
-- 주소창에 직접 입력하는 사용자가 이유를 알기 어렵고, 값은 어차피 검증을 거칩니다.
queryText :: Request -> [(Text, Maybe Text)]
queryText request =
  [(decodeUtf8Lenient key, fmap decodeUtf8Lenient value) | (key, value) <- queryString request]

-- | 헤더 이름은 대소문자를 구분하지 않습니다. WAI의 헤더 이름 타입이 이미 그렇게
-- 비교하므로 별도 정규화가 필요하지 않습니다.
headerText :: HeaderName -> Request -> Maybe Text
headerText name request = fmap decodeUtf8Lenient (lookup name (requestHeaders request))

decodeUtf8Lenient :: ByteString -> Text
decodeUtf8Lenient = Encoding.decodeUtf8With (\_ _ -> Just '\xFFFD')

tshow :: Int -> Text
tshow = Text.pack . show
