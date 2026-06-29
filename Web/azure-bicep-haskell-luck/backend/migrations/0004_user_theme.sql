-- 0004_user_theme.sql : 사용자별 색상 테마 저장
-- theme_key 는 프론트 THEMES 의 key(lime/lilac/navy/cream/mint/pink/coral) 중 하나.
-- 기본값 'lime' 은 프론트의 기본 테마와 일치한다.

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS theme_key text NOT NULL DEFAULT 'lime';
