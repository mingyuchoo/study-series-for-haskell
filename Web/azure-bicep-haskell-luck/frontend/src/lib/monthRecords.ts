// 월별 달력 격자 + 일별 달성 단계. 뷰(Calendar)에서 분리해 재사용·테스트 가능하게 한다.

import { createMemo, createResource, createSignal, type Accessor } from "solid-js";
import { api } from "./api";
import { fmt, monthGrid, monthLabel, type MonthCell } from "./date";
import { completionRatio, ratioToLevel } from "./luck";
import type { RecordDTO } from "./types";

export interface MonthRecordsState {
  cells: Accessor<MonthCell[]>;
  label: Accessor<string>;
  loading: Accessor<boolean>;
  /** 날짜("YYYY-MM-DD") -> 히트맵 단계(0~4). */
  level: (date: string) => number;
  prev: () => void;
  next: () => void;
}

export function createMonthRecords(): MonthRecordsState {
  const now = new Date();
  const [year, setYear] = createSignal(now.getFullYear());
  const [month, setMonth] = createSignal(now.getMonth()); // 0-based

  // 해당 월 1일 ~ 말일 범위의 기록을 가져온다
  const range = createMemo(() => {
    const first = new Date(year(), month(), 1);
    const last = new Date(year(), month() + 1, 0);
    return { from: fmt(first), to: fmt(last) };
  });

  const [records] = createResource(range, (r) => api.getRecords(r.from, r.to));

  // date -> 달성 비율 맵
  const ratioMap = createMemo(() => {
    const map = new Map<string, number>();
    const list: RecordDTO[] = records() ?? [];
    for (const rec of list) {
      map.set(rec.date, completionRatio(rec.completed.length, rec.total));
    }
    return map;
  });

  const cells = createMemo(() => monthGrid(year(), month()));
  const label = () => monthLabel(year(), month());
  const loading = () => records.loading;

  const prev = () => {
    if (month() === 0) {
      setYear(year() - 1);
      setMonth(11);
    } else setMonth(month() - 1);
  };
  const next = () => {
    if (month() === 11) {
      setYear(year() + 1);
      setMonth(0);
    } else setMonth(month() + 1);
  };

  // 임계값은 lib/luck 에서 관리.
  const level = (date: string): number => {
    const r = ratioMap().get(date);
    return r === undefined ? 0 : ratioToLevel(r);
  };

  return { cells, label, loading, level, prev, next };
}
