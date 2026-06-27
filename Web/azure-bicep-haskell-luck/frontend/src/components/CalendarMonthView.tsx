import { createSignal, For, Show, type Component } from "solid-js";
import { createMonthRecords } from "../lib/monthRecords";
import { recordStats } from "../lib/calendarStats";
import { catalog } from "../lib/catalog";
import { WEEKDAYS, todayStr, pad } from "../lib/date";

/** "달력" 탭 월간 뷰: 월간 통계 + 히트맵 격자 + 날짜 미리보기.
 *  "자세히 보기" 는 'onSelectDate' 로 알린다(라우팅은 호출 측 책임). */
const CalendarMonthView: Component<{ onSelectDate: (date: string) => void }> = (props) => {
  const cal = createMonthRecords();
  const [selected, setSelected] = createSignal(todayStr());

  const stats = () => {
    const totalDays = new Date(cal.year(), cal.month() + 1, 0).getDate();
    return { totalDays, ...recordStats(cal.records(), todayStr()) };
  };

  // 달 이동 시 선택을 그 달 1일로 옮긴다 (선택이 화면 밖이 되지 않도록).
  const firstOfMonth = () => `${cal.year()}-${pad(cal.month() + 1)}-01`;
  const goPrev = () => {
    cal.prev();
    setSelected(firstOfMonth());
  };
  const goNext = () => {
    cal.next();
    setSelected(firstOfMonth());
  };

  const selectedRecord = () => cal.recordFor(selected());
  const selectedDone = () => new Set(selectedRecord()?.completed ?? []);
  const doneCount = () => (catalog() ?? []).filter((i) => selectedDone().has(i.key)).length;

  return (
    <div class="cal-month">
      <div class="cal-nav">
        <button class="cal-arrow" onClick={goPrev} aria-label="이전 달">
          ‹
        </button>
        <h2>{cal.label()}</h2>
        <button class="cal-arrow" onClick={goNext} aria-label="다음 달">
          ›
        </button>
      </div>

      <Show when={!cal.loading()} fallback={<p class="muted-line">불러오는 중...</p>}>
        <div class="cal-stats">
          <div class="cal-stat">
            <span class="cal-stat-label">실천한 날</span>
            <span class="cal-stat-value">
              {stats().practiced}
              <span class="cal-stat-unit"> / {stats().totalDays}일</span>
            </span>
          </div>
          <div class="cal-stat">
            <span class="cal-stat-label">평균 달성률</span>
            <span class="cal-stat-value">
              {stats().avgPct}
              <span class="cal-stat-unit">%</span>
            </span>
          </div>
          <div class="cal-stat streak">
            <span class="cal-stat-label">현재 연속</span>
            <span class="cal-stat-value">
              {stats().currentStreak}
              <span class="cal-stat-unit">일</span>
            </span>
          </div>
          <div class="cal-stat">
            <span class="cal-stat-label">최고 연속</span>
            <span class="cal-stat-value">
              {stats().bestStreak}
              <span class="cal-stat-unit">일</span>
            </span>
          </div>
        </div>

        <div class="cal-monthbody">
          <div class="cal-gridwrap">
            <div class="weekrow">
              <For each={WEEKDAYS}>{(w) => <span class="wd">{w}</span>}</For>
            </div>
            <div class="calgrid">
              <For each={cal.cells()}>
                {(cell) => (
                  <button
                    class={`cal-cell lvl-${cal.level(cell.date)} ${cell.inMonth ? "" : "dim"} ${
                      cell.date === todayStr() ? "today" : ""
                    } ${cell.date === selected() ? "selected" : ""}`}
                    onClick={() => setSelected(cell.date)}
                  >
                    <span class="cell-day">{cell.day}</span>
                  </button>
                )}
              </For>
            </div>
          </div>

          <aside class="cal-preview">
            <div class="cal-preview-head">
              <span class="cal-preview-date">{selected()}</span>
              <Show when={catalog()}>
                <span class="cal-preview-count">
                  {doneCount()} / {catalog()!.length} 완료
                </span>
              </Show>
            </div>

            <Show when={catalog()} fallback={<p class="muted-line">불러오는 중...</p>}>
              <ul class="cal-preview-list">
                <For each={catalog()}>
                  {(item) => (
                    <li class={selectedDone().has(item.key) ? "done" : ""}>
                      <i
                        class={`ti ${selectedDone().has(item.key) ? "ti-circle-check" : "ti-circle"}`}
                        aria-hidden="true"
                      />
                      <span>{item.label}</span>
                    </li>
                  )}
                </For>
              </ul>

              <div class="cal-preview-memo">
                <span class="cal-preview-memo-label">메모</span>
                <Show when={selectedRecord()?.note} fallback={<p class="muted-line">메모 없음</p>}>
                  <p>{selectedRecord()!.note}</p>
                </Show>
              </div>

              <button class="cal-preview-more" onClick={() => props.onSelectDate(selected())}>
                자세히 보기 →
              </button>
            </Show>
          </aside>
        </div>
      </Show>
    </div>
  );
};

export default CalendarMonthView;
