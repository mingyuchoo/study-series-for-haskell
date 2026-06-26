-- 0002_admin_and_checklist.sql : 관리자 권한 + 체크리스트 항목 관리
-- users.is_admin     : 관리자 여부 (관리자만 체크리스트 CRUD 가능)
-- checklist_items    : 일별 체크리스트 항목 정본 (기존 하드코딩 catalog를 DB로 이관)
--
-- 이 파일은 서버 기동 시 0001 다음에 멱등적으로 실행된다.

-- 1) 관리자 컬럼 -------------------------------------------------------------
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS is_admin boolean NOT NULL DEFAULT false;

-- 2) 체크리스트 항목 테이블 --------------------------------------------------
CREATE TABLE IF NOT EXISTS checklist_items (
  key        text        PRIMARY KEY,
  label      text        NOT NULL,
  sort_order integer     NOT NULL DEFAULT 0,
  active     boolean     NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- active 컬럼은 나중에 추가되었으므로 기존 DB에도 멱등적으로 보강한다.
ALTER TABLE checklist_items
  ADD COLUMN IF NOT EXISTS active boolean NOT NULL DEFAULT true;

-- 3) 기존 하드코딩 항목 시드 (이미 있으면 건너뜀) ---------------------------
INSERT INTO checklist_items (key, label, sort_order) VALUES
  ('d1', '오늘 연락할 사람 한 명 정하고 연락하기 (오랜만인 사람 우선)', 1),
  ('d2', '평소와 다른 선택 한 가지 하기 (다른 길, 새 가게, 새 메뉴)', 2),
  ('d3', '떠오른 직감 하나를 메모해 두기', 3),
  ('d4', '마감과 목표에서 잠시 벗어나 ''다른 가능성은 없나'' 한 번 묻기', 4),
  ('d5', '잠들기 전 오늘 좋았던 일 세 가지 적기', 5)
ON CONFLICT (key) DO NOTHING;

-- 4) 최초 가입자(가장 먼저 가입한 사용자)를 관리자로 승격 -------------------
--    관리자가 아직 한 명도 없을 때에만 적용 → 멱등.
UPDATE users SET is_admin = true
WHERE id = (SELECT id FROM users ORDER BY created_at ASC, id ASC LIMIT 1)
  AND NOT EXISTS (SELECT 1 FROM users WHERE is_admin);
