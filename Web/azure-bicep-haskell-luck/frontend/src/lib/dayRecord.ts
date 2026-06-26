// 특정 날짜의 체크리스트 기록 상태 + 저장 로직. 뷰(Dashboard)에서 분리해 재사용·테스트 가능하게 한다.

import { createEffect, createResource, createSignal, type Accessor } from "solid-js";
import { api } from "./api";
import { hhmm } from "./date";
import { completionPct } from "./luck";
import type { CatalogItem } from "./types";

export interface DayRecordState {
  catalog: Accessor<CatalogItem[] | undefined>;
  completed: Accessor<string[]>;
  note: Accessor<string>;
  setNote: (v: string) => void;
  savedAt: Accessor<string>;
  total: Accessor<number>;
  pct: Accessor<number>;
  toggle: (key: string) => void;
  saveNote: () => void;
}

/** @param date 조회/저장 대상 날짜("YYYY-MM-DD")를 주는 접근자. */
export function createDayRecord(date: Accessor<string>): DayRecordState {
  const [catalog] = createResource(() => api.catalog.list());
  const [record] = createResource(date, (d) => api.records.get(d));

  const [completed, setCompleted] = createSignal<string[]>([]);
  const [note, setNote] = createSignal("");
  const [savedAt, setSavedAt] = createSignal("");

  // 서버 기록이 로드/변경되면 로컬 상태 동기화
  createEffect(() => {
    const r = record();
    if (r) {
      setCompleted(r.completed);
      setNote(r.note ?? "");
    }
  });

  const total = () => catalog()?.length ?? 0;
  const pct = () => completionPct(completed().length, total());

  const persist = async (next: string[], noteVal: string) => {
    try {
      await api.records.save(date(), next, noteVal.trim() === "" ? null : noteVal);
      setSavedAt(`${hhmm(new Date())} 저장됨`);
    } catch {
      setSavedAt("저장 실패 — 다시 시도하세요");
    }
  };

  const toggle = (key: string) => {
    const next = completed().includes(key)
      ? completed().filter((k) => k !== key)
      : [...completed(), key];
    setCompleted(next);
    void persist(next, note());
  };

  const saveNote = () => void persist(completed(), note());

  return { catalog, completed, note, setNote, savedAt, total, pct, toggle, saveNote };
}
