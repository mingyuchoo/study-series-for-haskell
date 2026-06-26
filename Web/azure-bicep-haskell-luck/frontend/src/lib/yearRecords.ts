// 연간 기록: 한 해 전체를 한 번에 받아 월별 미니 히트맵/연간 통계를 만든다.

import { createMemo, createResource, createSignal, type Accessor } from "solid-js";
import { api } from "./api";
import { completionRatio, ratioToLevel } from "./luck";
import type { RecordDTO } from "./types";

export interface YearRecordsState {
  year: Accessor<number>;
  loading: Accessor<boolean>;
  records: Accessor<RecordDTO[]>;
  /** 날짜("YYYY-MM-DD") -> 히트맵 단계(0~4). */
  level: (date: string) => number;
  prev: () => void;
  next: () => void;
}

export function createYearRecords(): YearRecordsState {
  const now = new Date();
  const [year, setYear] = createSignal(now.getFullYear());

  const range = createMemo(() => ({ from: `${year()}-01-01`, to: `${year()}-12-31` }));
  const [records] = createResource(range, (r) => api.records.list(r.from, r.to));

  const ratioMap = createMemo(() => {
    const m = new Map<string, number>();
    for (const rec of records() ?? []) {
      m.set(rec.date, completionRatio(rec.completed.length, rec.total));
    }
    return m;
  });

  const list = () => records() ?? [];
  const loading = () => records.loading;
  const level = (date: string): number => ratioToLevel(ratioMap().get(date) ?? 0);

  return {
    year,
    loading,
    records: list,
    level,
    prev: () => setYear(year() - 1),
    next: () => setYear(year() + 1),
  };
}
