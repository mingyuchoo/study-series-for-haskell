-- 0005_verification_attempts.sql : 인증번호 확인 시도 횟수 제한
-- 계정(이메일)별로 verify 시도를 제한해 6자리 코드 brute-force 를 막는다.
-- IP 레이트리밋과 독립적으로, 코드 1건당 시도 횟수를 상한으로 묶는다.
-- 코드를 재요청(upsert)하면 attempts 는 0 으로 초기화된다.

ALTER TABLE signup_verifications
  ADD COLUMN IF NOT EXISTS attempts int NOT NULL DEFAULT 0;
