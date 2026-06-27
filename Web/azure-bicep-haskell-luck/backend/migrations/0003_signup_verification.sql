-- 0003_signup_verification.sql : 회원가입 이메일 인증
-- signup_verifications: 인증번호 확인 전까지 가입 정보를 임시 보관한다.
--   사용자가 6자리 인증번호를 확인하면 users 로 승격되고 이 행은 삭제된다.
--   email 을 PK 로 두어 같은 이메일 재요청 시 ON CONFLICT 로 코드를 재발급한다.

CREATE TABLE IF NOT EXISTS signup_verifications (
  email         text        PRIMARY KEY,
  password_hash text        NOT NULL,
  display_name  text        NOT NULL,
  code          text        NOT NULL,        -- 6자리 인증번호 (앞자리 0 보존 위해 text)
  expires_at    timestamptz NOT NULL
);
