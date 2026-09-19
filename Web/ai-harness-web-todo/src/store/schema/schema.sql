-- store가 소유하는 Canonical SQLite 스키마입니다.
-- 이 파일이 원본이며 docs/generated/db-schema.md는 여기에서 생성됩니다.
-- 필드의 비즈니스 의미와 보존 정책은 docs/contracts/data/TODO-STORE-v1.md에 있습니다.
--
-- 규칙
--   1. 시각은 UTC ISO 8601 문자열로 저장합니다.
--   2. 날짜는 YYYY-MM-DD 문자열로 저장합니다.
--   3. 상태와 우선순위는 Todo.Core.Types의 안정적인 이름을 그대로 저장합니다.

CREATE TABLE IF NOT EXISTS schema_version (
    version     INTEGER NOT NULL,
    applied_at  TEXT    NOT NULL
);

CREATE TABLE IF NOT EXISTS todos (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    title       TEXT    NOT NULL,
    list_id     TEXT    NOT NULL,
    status      TEXT    NOT NULL,
    priority    TEXT    NOT NULL,
    due_on      TEXT,
    created_at  TEXT    NOT NULL,
    updated_at  TEXT    NOT NULL
);

CREATE TABLE IF NOT EXISTS todo_tags (
    todo_id     INTEGER NOT NULL REFERENCES todos(id) ON DELETE CASCADE,
    tag         TEXT    NOT NULL,
    PRIMARY KEY (todo_id, tag)
);

CREATE INDEX IF NOT EXISTS idx_todos_status  ON todos(status);

CREATE INDEX IF NOT EXISTS idx_todos_list_id ON todos(list_id);

CREATE INDEX IF NOT EXISTS idx_todos_due_on  ON todos(due_on);

CREATE INDEX IF NOT EXISTS idx_todo_tags_tag ON todo_tags(tag)
