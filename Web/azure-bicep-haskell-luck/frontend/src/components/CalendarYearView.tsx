import { For, Show } from "solid-js";
import { useNavigate } from "@solidjs/router";
import { createYearRecords } from "../lib/yearRecords";
import { recordStats } from "../lib/calendarStats";
import { todayStr, pad } from "../lib/date";

interface MiniCell {
  date: string | null;
}

/** 한 달치 미니 셀(선행 빈칸 + 1일~말일). */
function miniMonth(year: number, month: number): MiniCell[] {
  const daysIn = new Date(year, month + 1, 0).getDate();
  const lead = new Date(year, month, 1).getDay();
  const cells: MiniCell[] = [];
  for (let i = 0; i < lead; i++) cells.push({ date: null });
  for (let d = 1; d <= daysIn; d++) cells.push({ date: `${year}-${pad(month + 1)}-${pad(d)}` });
  return cells;
}

/** "달력" 탭 연간 뷰: 12개월 미니 히트맵 + 연간 통계. */
export default function CalendarYearView() {
  const navigate = useNavigate();
  const yr = createYearRecords();
  const stats = () => recordStats(yr.records(), todayStr());
  const months = Array.from({ length: 12 }, (_, m) => m);

  return (
    <div class="cal-year">
      <div class="cal-nav">
        <button class="cal-arrow" onClick={yr.prev} aria-label="이전 해">
          ‹
        </button>
        <h2>{yr.year()}년</h2>
        <button class="cal-arrow" onClick={yr.next} aria-label="다음 해">
          ›
        </button>
      </div>

      <Show when={!yr.loading()} fallback={<p class="muted-line">불러오는 중...</p>}>
        <p class="cal-year-summary">
          실천일 {stats().practiced}일 · 평균 {stats().avgPct}% · 최고 연속 {stats().bestStreak}일
        </p>

        <div class="cal-yeargrid">
          <For each={months}>
            {(m) => (
              <div class="cal-minimonth">
                <p class="cal-minilabel">{m + 1}월</p>
                <div class="cal-minicells">
                  <For each={miniMonth(yr.year(), m)}>
                    {(c) => (
                      <Show when={c.date} fallback={<span class="cal-minicell empty" />}>
                        <button
                          class={`cal-minicell lvl-${yr.level(c.date!)} ${
                            c.date === todayStr() ? "today" : ""
                          }`}
                          title={c.date!}
                          aria-label={c.date!}
                          onClick={() => navigate(`/day/${c.date}`)}
                        />
                      </Show>
                    )}
                  </For>
                </div>
              </div>
            )}
          </For>
        </div>

        <div class="legend">
          <span class="muted-line">적음</span>
          <span class="lg lvl-1" />
          <span class="lg lvl-2" />
          <span class="lg lvl-3" />
          <span class="lg lvl-4" />
          <span class="muted-line">많음</span>
        </div>
      </Show>
    </div>
  );
}
