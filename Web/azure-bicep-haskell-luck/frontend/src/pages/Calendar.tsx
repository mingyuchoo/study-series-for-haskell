import { For, Show } from "solid-js";
import { useNavigate } from "@solidjs/router";
import { createMonthRecords } from "../lib/monthRecords";
import { WEEKDAYS, todayStr } from "../lib/date";

export default function Calendar() {
  const navigate = useNavigate();
  const cal = createMonthRecords();

  return (
    <div class="page">
      <header class="page-head cal-head">
        <span class="eyebrow">曆 · 일별 기록</span>
        <div class="cal-nav">
          <button class="cal-arrow" onClick={cal.prev} aria-label="이전 달">
            ‹
          </button>
          <h2>{cal.label()}</h2>
          <button class="cal-arrow" onClick={cal.next} aria-label="다음 달">
            ›
          </button>
        </div>
      </header>

      <div class="weekrow">
        <For each={WEEKDAYS}>{(w) => <span class="wd">{w}</span>}</For>
      </div>

      <Show when={!cal.loading()} fallback={<p class="muted-line">불러오는 중...</p>}>
        <div class="calgrid">
          <For each={cal.cells()}>
            {(cell) => (
              <button
                class={`cal-cell lvl-${cal.level(cell.date)} ${cell.inMonth ? "" : "dim"} ${
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
