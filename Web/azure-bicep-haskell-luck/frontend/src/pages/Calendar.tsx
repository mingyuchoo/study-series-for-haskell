import { createSignal, Show } from "solid-js";
import CalendarMonthView from "../components/CalendarMonthView";
import CalendarYearView from "../components/CalendarYearView";

type View = "month" | "year";

/** "달력" 탭: 월간/연간 토글. "오늘" 탭의 단순 달력과 달리 통계·미리보기·연간 히트맵을 제공한다. */
export default function Calendar() {
  const [view, setView] = createSignal<View>("month");

  return (
    <div class="page cal-page">
      <header class="cal-pagehead">
        <span class="eyebrow">曆 · 일별 기록</span>
        <div class="cal-toggle">
          <button class={view() === "month" ? "active" : ""} onClick={() => setView("month")}>
            월간
          </button>
          <button class={view() === "year" ? "active" : ""} onClick={() => setView("year")}>
            연간
          </button>
        </div>
      </header>

      <Show when={view() === "month"} fallback={<CalendarYearView />}>
        <CalendarMonthView />
      </Show>
    </div>
  );
}
