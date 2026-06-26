import { For, Show } from "solid-js";
import { useParams } from "@solidjs/router";
import { createDayRecord } from "../lib/dayRecord";
import { imeInput } from "../lib/ime";
import { PRINCIPLES } from "../lib/principles";
import { todayStr } from "../lib/date";
import Medallion from "../components/Medallion";
import Checklist from "../components/Checklist";
import MonthCalendar from "../components/MonthCalendar";

export default function Dashboard() {
  const params = useParams();
  const date = () => params.date ?? todayStr();
  const isToday = () => date() === todayStr();

  const day = createDayRecord(date);

  return (
    <div class="page dash">
      {/* ① 心法 · 마음의 4원칙 — 최상단 */}
      <section class="principles">
        <span class="eyebrow">心法 · 마음의 4원칙</span>
        <div class="cards">
          <For each={PRINCIPLES}>
            {(c) => (
              <div class="pcard" data-n={c.n}>
                <h3>{c.h}</h3>
                <p>{c.p}</p>
              </div>
            )}
          </For>
        </div>
      </section>

      {/* ② 오늘의 실천 — 좌측 요약 + 우측 체크리스트/메모 */}
      <section class="dash-today">
        <header class="dash-head">
          <span class="eyebrow">{isToday() ? "오늘의 실천" : "지난 기록"}</span>
          <h2 class="dash-date">{date()}</h2>
          <Medallion pct={day.pct()} />
          <div class="dash-stat">
            <span class="big">{day.pct()}%</span>
            <span class="muted-line">
              {day.completed().length} / {day.total()} 항목 완료
            </span>
          </div>
        </header>

        <div class="dash-main">
          <Show when={day.catalog()} fallback={<p class="muted-line">불러오는 중...</p>}>
            <Checklist items={day.catalog()!} completed={day.completed()} onToggle={day.toggle} />
          </Show>
        </div>

        {/* 메모는 칼럼을 벗어나 섹션 전체 폭(運 칼럼 왼쪽 끝까지)을 차지한다 */}
        <label class="field note-field">
          <span>오늘의 메모</span>
          <textarea
            rows="3"
            value={day.note()}
            {...imeInput(day.setNote)}
            onBlur={day.saveNote}
            placeholder="좋았던 일, 떠오른 직감 등을 적어 두세요"
          />
        </label>
        <Show when={day.savedAt()}>
          <p class="save-hint">{day.savedAt()}</p>
        </Show>
      </section>

      {/* ③ 달력 — 일별 기록 히트맵 */}
      <section class="dash-calendar">
        <MonthCalendar />
      </section>
    </div>
  );
}
