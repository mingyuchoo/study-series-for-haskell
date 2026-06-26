import { createMemo, createResource, createSignal, For, Show } from "solid-js";
import { useNavigate } from "@solidjs/router";
import { api, type RecordDTO } from "../lib/api";
import { monthGrid, monthLabel, WEEKDAYS, fmt, todayStr } from "../lib/date";

export default function Calendar() {
  const navigate = useNavigate();
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
      const ratio = rec.total === 0 ? 0 : rec.completed.length / rec.total;
      map.set(rec.date, ratio);
    }
    return map;
  });

  const cells = createMemo(() => monthGrid(year(), month()));

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

  // 달성률 -> 0~4 단계 (CSS 클래스용)
  const level = (date: string): number => {
    const r = ratioMap().get(date);
    if (r === undefined || r === 0) return 0;
    if (r >= 1) return 4;
    if (r >= 0.75) return 3;
    if (r >= 0.5) return 2;
    return 1;
  };

  return (
    <div class="page">
      <header class="page-head cal-head">
        <span class="eyebrow">曆 · 일별 기록</span>
        <div class="cal-nav">
          <button class="cal-arrow" onClick={prev} aria-label="이전 달">
            ‹
          </button>
          <h2>{monthLabel(year(), month())}</h2>
          <button class="cal-arrow" onClick={next} aria-label="다음 달">
            ›
          </button>
        </div>
      </header>

      <div class="weekrow">
        <For each={WEEKDAYS}>{(w) => <span class="wd">{w}</span>}</For>
      </div>

      <Show when={!records.loading} fallback={<p class="muted-line">불러오는 중...</p>}>
        <div class="calgrid">
          <For each={cells()}>
            {(cell) => (
              <button
                class={`cal-cell lvl-${level(cell.date)} ${cell.inMonth ? "" : "dim"} ${
                  cell.date === todayStr() ? "today" : ""
                }`}
                onClick={() => navigate(`/day/${cell.date}`)}
              >
                <span class="cell-day">{cell.day}</span>
              </button>
            )}
          </For>
        </div>
      </Show>

      <div class="legend">
        <span class="muted-line">적음</span>
        <span class="lg lvl-1" />
        <span class="lg lvl-2" />
        <span class="lg lvl-3" />
        <span class="lg lvl-4" />
        <span class="muted-line">많음</span>
      </div>
    </div>
  );
}
