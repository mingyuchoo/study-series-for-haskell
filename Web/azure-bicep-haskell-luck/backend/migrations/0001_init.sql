-- 0001_init.sql : 초기 스키마
-- users: 계정 + 프로필
-- daily_records: 날짜별 체크리스트 기록 (달력 뷰의 원천)

CREATE TABLE IF NOT EXISTS users (
  id            uuid        PRIMARY KEY,
  email         text        NOT NULL UNIQUE,
  password_hash text        NOT NULL,
  display_name  text        NOT NULL,
  bio           text        NOT NULL DEFAULT '',
  timezone      text        NOT NULL DEFAULT 'Asia/Seoul',
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS daily_records (
  user_id     uuid        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  record_date date        NOT NULL,
  completed   jsonb       NOT NULL DEFAULT '[]'::jsonb,  -- 완료한 항목 key 배열
  note        text,
  updated_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, record_date)
);

CREATE INDEX IF NOT EXISTS idx_daily_records_user_date
  ON daily_records (user_id, record_date);
