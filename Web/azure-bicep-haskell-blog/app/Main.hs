-- | 실행 진입점: 설정 로드 → 풀 생성 → 마이그레이션 → 서버 시작.
module Main
  ( main
  ) where

import Data.Text (Text)
import Network.HTTP.Client.TLS (newTlsManager)
import System.Exit (exitFailure)
import System.IO
  ( BufferMode (LineBuffering)
  , hPutStrLn
  , hSetBuffering
  , hSetEncoding
  , stderr
  , stdout
  , utf8
  )
import Web.Scotty (scotty)

import Blog.App (Env (..), application)
import Blog.Config (AppConfig (..), loadConfig)
import Blog.Database
  ( newDbPool
  , postgresStore
  , postgresUserStore
  , postgresVerificationStore
  , runMigrations
  )
import Blog.Email (EmailSender, logEmailSender)
import Blog.Email.Acs (acsEmailSender, parseAcsConnectionString)
import Blog.Keys (deriveKeys)

main :: IO ()
main = do
  -- 컨테이너 로케일이 C(ASCII)여도 한글 로그를 출력할 수 있도록 UTF-8 강제.
  -- (미설정 시 stderr 출력에서 "commitBuffer: invalid argument (cannot encode character)" 발생)
  hSetEncoding stdout utf8
  hSetEncoding stderr utf8

  -- 컨테이너 로그가 즉시 보이도록 라인 버퍼링
  hSetBuffering stdout LineBuffering
  hSetBuffering stderr LineBuffering

  result <- loadConfig
  case result of
    Left err -> do
      hPutStrLn stderr ("설정 오류: " ++ err)
      exitFailure
    Right cfg -> do
      -- PREVIEW_SECRET 미설정 시 개발용 기본키를 쓰고 있음을 크게 경고한다.
      if configInsecureKey cfg
        then hPutStrLn stderr "경고: PREVIEW_SECRET 미설정 — 개발용 기본키로 동작합니다. 프로덕션에서는 반드시 설정하세요."
        else pure ()
      pool <- newDbPool (configDatabaseUrl cfg)
      runMigrations pool
      sender <- resolveSender (configAcs cfg)
      hPutStrLn stderr ("haskell-blog: 포트 " ++ show (configPort cfg) ++ " 에서 수신 대기")
      -- 조립 루트: 구체 구현(postgresUserStore/postgresStore)을 추상 인터페이스로
      -- 묶어 주입하고, 마스터 비밀에서 파생한 용도별 서명 키를 함께 전달한다.
      scotty
        (configPort cfg)
        ( application
            Env
              { envKeys = deriveKeys (configSecretKey cfg)
              , envUsers = postgresUserStore pool
              , envPosts = postgresStore pool
              , envSender = sender
              , envVerify = postgresVerificationStore pool
              }
        )

-- | ACS 설정이 있으면 실제 이메일 발송 어댑터를, 없거나 파싱 실패면 로그 폴백을 고른다.
resolveSender :: Maybe (Text, Text) -> IO EmailSender
resolveSender Nothing = do
  hPutStrLn stderr "이메일: ACS 미설정 — 인증 코드를 stderr 로 출력합니다(logEmailSender)."
  pure logEmailSender
resolveSender (Just (conn, addr)) =
  case parseAcsConnectionString conn addr of
    Right acsCfg -> do
      mgr <- newTlsManager
      hPutStrLn stderr "이메일: Azure Communication Services 로 인증 코드를 발송합니다."
      pure (acsEmailSender mgr acsCfg)
    Left err -> do
      hPutStrLn stderr ("이메일: ACS 설정 파싱 실패 — 로그 폴백. " ++ err)
      pure logEmailSender
