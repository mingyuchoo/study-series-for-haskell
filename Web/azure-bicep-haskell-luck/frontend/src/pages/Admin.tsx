import { createSignal, For, Show } from "solid-js";
import { createAdminCatalog } from "../lib/adminCatalog";
import { imeInput } from "../lib/ime";
import type { AdminCatalogItem } from "../lib/types";

/** 관리자 전용: 체크리스트 항목(catalog) CRUD 페이지 (얇은 뷰).
 *  데이터/동작은 createAdminCatalog 프레젠터, 인가는 RequireAdmin 가드가 담당한다. */
export default function Admin() {
  const cat = createAdminCatalog();

  // 폼/인라인 수정용 뷰 상태
  const [newLabel, setNewLabel] = createSignal("");
  const [adding, setAdding] = createSignal(false);
  const [editKey, setEditKey] = createSignal<string | null>(null);
  const [editLabel, setEditLabel] = createSignal("");

  const submitAdd = async (e: Event) => {
    e.preventDefault();
    setAdding(true);
    const added = await cat.add(newLabel());
    if (added) setNewLabel("");
    setAdding(false);
  };

  const startEdit = (item: AdminCatalogItem) => {
    setEditKey(item.key);
    setEditLabel(item.label);
  };
  const cancelEdit = () => {
    setEditKey(null);
    setEditLabel("");
  };
  const submitEdit = async (key: string) => {
    if (await cat.saveEdit(key, editLabel())) cancelEdit();
  };
  const confirmRemove = (key: string) => {
    if (confirm(`'${key}' 항목을 삭제할까요?`)) void cat.remove(key);
  };

  return (
    <div class="page">
      <header class="page-head">
        <span class="eyebrow">管理</span>
        <h2>체크리스트 항목 관리</h2>
      </header>

      <Show when={cat.err()}>
        <p class="form-error">{cat.err()}</p>
      </Show>
      <Show when={cat.ok()}>
        <p class="form-ok">{cat.ok()}</p>
      </Show>

      <Show when={!cat.loading()} fallback={<p class="muted-line">불러오는 중...</p>}>
        {/* 추가 폼 — KEY는 서버가 자동 생성한다 */}
        <form class="card-form admin-add" onSubmit={submitAdd}>
          <label class="field">
            <span>내용</span>
            <input
              type="text"
              value={newLabel()}
              {...imeInput(setNewLabel)}
              placeholder="체크리스트에 표시할 문구"
              maxlength="200"
            />
          </label>
          <button class="btn-primary" type="submit" disabled={adding()}>
            {adding() ? "추가 중..." : "항목 추가"}
          </button>
          <p class="admin-hint">KEY는 저장 시 자동으로 생성됩니다 (예: d6).</p>
        </form>

        {/* 목록 */}
        <Show
          when={cat.items().length > 0}
          fallback={<p class="muted-line">등록된 항목이 없습니다.</p>}
        >
          <div class="list admin-list">
            <For each={cat.items()}>
              {(item) => (
                <div class={`admin-row${item.active ? "" : " inactive"}`}>
                  <label
                    class="admin-toggle"
                    title={item.active ? "활성 — 오늘 탭에 표시됨" : "비활성 — 오늘 탭에서 숨김"}
                  >
                    <input
                      type="checkbox"
                      checked={item.active}
                      disabled={cat.busyKey() === item.key}
                      onChange={() => cat.toggleActive(item)}
                    />
                  </label>
                  <span class="admin-key">{item.key}</span>
                  <Show
                    when={editKey() === item.key}
                    fallback={<span class="admin-label">{item.label}</span>}
                  >
                    <input
                      class="admin-edit-input"
                      type="text"
                      value={editLabel()}
                      {...imeInput(setEditLabel)}
                      maxlength="200"
                    />
                  </Show>
                  <Show when={!item.active}>
                    <span class="admin-badge">비활성</span>
                  </Show>
                  <div class="admin-actions">
                    <Show
                      when={editKey() === item.key}
                      fallback={
                        <>
                          <button
                            class="admin-btn"
                            onClick={() => startEdit(item)}
                            disabled={cat.busyKey() === item.key}
                          >
                            수정
                          </button>
                          <button
                            class="admin-btn danger"
                            onClick={() => confirmRemove(item.key)}
                            disabled={cat.busyKey() === item.key}
                          >
                            삭제
                          </button>
                        </>
                      }
                    >
                      <button
                        class="admin-btn"
                        onClick={() => submitEdit(item.key)}
                        disabled={cat.busyKey() === item.key}
                      >
                        {cat.busyKey() === item.key ? "저장 중..." : "저장"}
                      </button>
                      <button class="admin-btn" onClick={cancelEdit}>
                        취소
                      </button>
                    </Show>
                  </div>
                </div>
              )}
            </For>
          </div>
        </Show>
      </Show>
    </div>
  );
}
