// 관리자 카탈로그 CRUD 상태 + 동작. 뷰(Admin)에서 분리해 재사용·테스트 가능하게 한다.
// (Dashboard의 createDayRecord, Calendar의 createMonthRecords 와 같은 프레젠터 패턴.)

import { createSignal, onMount, type Accessor } from "solid-js";
import { api } from "./api";
import { ApiError } from "./http";
import type { AdminCatalogItem } from "./types";

export interface AdminCatalogState {
  items: Accessor<AdminCatalogItem[]>;
  loading: Accessor<boolean>;
  err: Accessor<string>;
  ok: Accessor<string>;
  /** 현재 변이 중인 항목 key (버튼 비활성화용). */
  busyKey: Accessor<string | null>;
  /** 항목 추가. 성공 시 true. */
  add: (label: string) => Promise<boolean>;
  /** 활성/비활성 토글. */
  toggleActive: (item: AdminCatalogItem) => Promise<void>;
  /** 라벨 수정. 성공 시 true. */
  saveEdit: (key: string, label: string) => Promise<boolean>;
  /** 항목 삭제. */
  remove: (key: string) => Promise<void>;
}

export function createAdminCatalog(): AdminCatalogState {
  const [items, setItems] = createSignal<AdminCatalogItem[]>([]);
  const [loading, setLoading] = createSignal(true);
  const [err, setErr] = createSignal("");
  const [ok, setOk] = createSignal("");
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
    try {
      setItems(await api.admin.list());
    } catch (ex) {
      fail(ex, "항목을 불러오지 못했습니다.");
    } finally {
      setLoading(false);
    }
  });

  const add = async (label: string): Promise<boolean> => {
    const l = label.trim();
    if (!l) {
      fail(null, "내용을 입력하세요.");
      return false;
    }
    try {
      const created = await api.admin.create(l);
      setItems([...items(), created]);
      flash("항목이 추가되었습니다.");
      return true;
    } catch (ex) {
      fail(ex, "항목 추가에 실패했습니다.");
      return false;
    }
  };

  const toggleActive = async (item: AdminCatalogItem): Promise<void> => {
    setBusyKey(item.key);
    try {
      const updated = await api.admin.setActive(item.key, !item.active);
      setItems(items().map((it) => (it.key === item.key ? updated : it)));
      flash(updated.active ? "항목을 활성화했습니다." : "항목을 비활성화했습니다.");
    } catch (ex) {
      fail(ex, "활성 상태 변경에 실패했습니다.");
    } finally {
      setBusyKey(null);
    }
  };

  const saveEdit = async (key: string, label: string): Promise<boolean> => {
    const l = label.trim();
    if (!l) {
      fail(null, "내용을 입력하세요.");
      return false;
    }
    setBusyKey(key);
    try {
      const updated = await api.admin.update(key, l);
      setItems(items().map((it) => (it.key === key ? updated : it)));
      flash("수정되었습니다.");
      return true;
    } catch (ex) {
      fail(ex, "수정에 실패했습니다.");
      return false;
    } finally {
      setBusyKey(null);
    }
  };

  const remove = async (key: string): Promise<void> => {
    setBusyKey(key);
    try {
      await api.admin.remove(key);
      setItems(items().filter((it) => it.key !== key));
      flash("삭제되었습니다.");
    } catch (ex) {
      fail(ex, "삭제에 실패했습니다.");
    } finally {
      setBusyKey(null);
    }
  };

  return { items, loading, err, ok, busyKey, add, toggleActive, saveEdit, remove };
}
