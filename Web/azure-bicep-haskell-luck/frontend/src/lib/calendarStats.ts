// 달력 통계(순수): 실천일 / 평균 달성률 / 연속(스트릭) 계산. 뷰·DB를 모른다.

import type { RecordDTO } from "./types";
import { completionRatio } from "./luck";
import { parse } from "./date";

export interface RecordStats {
  /** 실천한 날 (완료 항목 1개 이상). */
  practiced: number;
  /** 실천한 날들의 평균 달성률(%). */
  avgPct: number;
  /** 오늘 기준 거슬러 올라가며 연속으로 실천한 일수. */
  currentStreak: number;
  /** 기록 범위 내 최장 연속 실천 일수. */
  bestStreak: number;
}

/** "YYYY-MM-DD" → 일 단위 정수(연속 여부 판정용). */
function dayNum(date: string): number {
  return Math.round(parse(date).getTime() / 86_400_000);
}

/** 완료 1개 이상인 날의 date→달성비율 맵. */
function practicedRatios(records: RecordDTO[]): Map<string, number> {
  const m = new Map<string, number>();
  for (const r of records) {
    if (r.completed.length > 0) m.set(r.date, completionRatio(r.completed.length, r.total));
  }
  return m;
}

/** 기록 목록에서 실천일·평균 달성률·연속 기록을 집계한다. */
export function recordStats(records: RecordDTO[], today: string): RecordStats {
  const ratios = practicedRatios(records);
  const practiced = ratios.size;
  const avgPct =
    practiced === 0
      ? 0
      : Math.round(([...ratios.values()].reduce((a, b) => a + b, 0) / practiced) * 100);

  // 최장 연속: 실천일을 일 단위로 정렬해 인접(차이 1) 구간의 최대 길이
  const days = [...ratios.keys()].map(dayNum).sort((a, b) => a - b);
  let best = 0;
  let run = 0;
  let prevDay = NaN;
  for (const d of days) {
    run = d === prevDay + 1 ? run + 1 : 1;
    if (run > best) best = run;
    prevDay = d;
  }

  // 현재 연속: 오늘부터 하루씩 거슬러 올라가며 실천일이 끊기기 전까지
  const set = new Set(days);
  let current = 0;
  for (let d = dayNum(today); set.has(d); d--) current++;

  return { practiced, avgPct, currentStreak: current, bestStreak: best };
}
