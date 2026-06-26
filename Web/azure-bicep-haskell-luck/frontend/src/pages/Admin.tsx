import { createSignal, For, onMount, Show } from "solid-js";
import { useNavigate } from "@solidjs/router";
import { api } from "../lib/api";
import { ApiError } from "../lib/http";
import { auth } from "../lib/store";
import type { CatalogItem } from "../lib/types";

/** 관리자 전용: 체크리스트 항목(catalog) CRUD 페이지. */
export default function Admin() {
  const navigate = useNavigate();

  const [items, setItems] = createSignal<CatalogItem[]>([]);
  const [loading, setLoading] = createSignal(true);
  const [err, setErr] = createSignal("");
  const [ok, setOk] = createSignal("");

  // 추가 폼 (KEY는 서버가 자동 생성하므로 입력받지 않는다)
  const [newLabel, setNewLabel] = createSignal("");
  const [adding, setAdding] = createSignal(false);

  // 인라인 수정 상태
  const [editKey, setEditKey] = createSignal<string | null>(null);
  const [editLabel, setEditLabel] = createSignal("");
  const [busyKey, setBusyKey] = createSignal<string | null>(null);

  const flash = (message: string) => {
    setOk(message);
    setErr("");
  };
  const fail = (ex: unknown, fallback: string) => {
    setErr(ex instanceof ApiError ? ex.message : fallback);
    setOk("");
  };

  onMount(async () => {
    // 관리자 여부 확인 — 비관리자는 메인으로 돌려보낸다 (UI 차원의 방어, 권한은 서버가 강제)
    try {
      const me = await api.me();
      auth.setUser(me);
      if (!me.isAdmin) {
        navigate("/", { replace: true });
        return;
      }
      setItems(await api.adminCatalog());
    } catch (ex) {
      fail(ex, "항목을 불러오지 못했습니다.");
    } finally {
      setLoading(false);
    }
  });

  const add = async (e: Event) => {
    e.preventDefault();
    const label = newLabel().trim();
    if (!label) {
      fail(null, "내용을 입력하세요.");
      return;
    }
    setAdding(true);
    try {
      const created = await api.createCatalogItem(label);
      setItems([...items(), created]);
      setNewLabel("");
      flash("항목이 추가되었습니다.");
    } catch (ex) {
      fail(ex, "항목 추가에 실패했습니다.");
    } finally {
      setAdding(false);
    }
  };

  const toggleActive = async (item: CatalogItem) => {
    setBusyKey(item.key);
    try {
      const updated = await api.setCatalogItemActive(item.key, !item.active);
      setItems(items().map((it) => (it.key === item.key ? updated : it)));
      flash(updated.active ? "항목을 활성화했습니다." : "항목을 비활성화했습니다.");
    } catch (ex) {
      fail(ex, "활성 상태 변경에 실패했습니다.");
    } finally {
      setBusyKey(null);
    }
  };

  const startEdit = (item: CatalogItem) => {
    setEditKey(item.key);
    setEditLabel(item.label);
    setErr("");
    setOk("");
  };

  const cancelEdit = () => {
    setEditKey(null);
    setEditLabel("");
  };

  const saveEdit = async (key: string) => {
    const label = editLabel().trim();
    if (!label) {
      fail(null, "내용을 입력하세요.");
      return;
    }
    setBusyKey(key);
    try {
      const updated = await api.updateCatalogItem(key, label);
      setItems(items().map((it) => (it.key === key ? updated : it)));
      cancelEdit();
      flash("수정되었습니다.");
    } catch (ex) {
      fail(ex, "수정에 실패했습니다.");
    } finally {
      setBusyKey(null);
    }
  };

  const remove = async (key: string) => {
    if (!confirm(`'${key}' 항목을 삭제할까요?`)) return;
    setBusyKey(key);
    try {
      await api.deleteCatalogItem(key);
      setItems(items().filter((it) => it.key !== key));
      flash("삭제되었습니다.");
    } catch (ex) {
      fail(ex, "삭제에 실패했습니다.");
    } finally {
      setBusyKey(null);
    }
  };

  return (
    <div class="page">
      <header class="page-head">
        <span class="eyebrow">管理</span>
        <h2>체크리스트 항목 관리</h2>
      </header>

      <Show when={err()}>
        <p class="form-error">{err()}</p>
      </Show>
      <Show when={ok()}>
        <p class="form-ok">{ok()}</p>
      </Show>

      <Show when={!loading()} fallback={<p class="muted-line">불러오는 중...</p>}>
        {/* 추가 폼 — KEY는 서버가 자동 생성한다 */}
        <form class="card-form admin-add" onSubmit={add}>
          <label class="field">
            <span>내용</span>
            <input
              type="text"
              value={newLabel()}
              onInput={(e) => {
                if (e.isComposing) return;
                setNewLabel(e.currentTarget.value);
              }}
              onCompositionEnd={(e) => setNewLabel(e.currentTarget.value)}
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
          when={items().length > 0}
          fallback={<p class="muted-line">등록된 항목이 없습니다.</p>}
        >
          <div class="list admin-list">
            <For each={items()}>
              {(item) => (
                <div class={`admin-row${item.active ? "" : " inactive"}`}>
                  <label class="admin-toggle" title={item.active ? "활성 — 오늘 탭에 표시됨" : "비활성 — 오늘 탭에서 숨김"}>
                    <input
                      type="checkbox"
                      checked={item.active}
                      disabled={busyKey() === item.key}
                      onChange={() => toggleActive(item)}
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
                      onInput={(e) => {
                        if (e.isComposing) return;
                        setEditLabel(e.currentTarget.value);
                      }}
                      onCompositionEnd={(e) => setEditLabel(e.currentTarget.value)}
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
                            disabled={busyKey() === item.key}
                          >
                            수정
                          </button>
                          <button
                            class="admin-btn danger"
                            onClick={() => remove(item.key)}
                            disabled={busyKey() === item.key}
                          >
                            삭제
                          </button>
                        </>
                      }
                    >
                      <button
                        class="admin-btn"
                        onClick={() => saveEdit(item.key)}
                        disabled={busyKey() === item.key}
                      >
                        {busyKey() === item.key ? "저장 중..." : "저장"}
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
