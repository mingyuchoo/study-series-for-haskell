import { createEffect, createResource, createSignal, For, Show } from "solid-js";
import { useParams } from "@solidjs/router";
import { api } from "../lib/api";
import { todayStr } from "../lib/date";
import Medallion from "../components/Medallion";
import Checklist from "../components/Checklist";

const PRINCIPLES = [
  { n: "一", h: "기회를 넓힌다", p: "인맥과 경험의 폭을 키우고 긴장을 푼다. 시야가 좁아지면 옆의 기회를 놓친다." },
  { n: "二", h: "직감을 따른다", p: "경험에서 우러난 직감을 신뢰하고, 그 감각을 꾸준히 키운다." },
  { n: "三", h: "행운을 기대한다", p: "미래에 대한 긍정적 기대를 갖고 끈기 있게 다시 시도한다." },
  { n: "四", h: "불운을 뒤집는다", p: "나쁜 일에서도 배움과 또 다른 기회를 찾아 회복한다." },
];

export default function Dashboard() {
  const params = useParams();
  const date = () => params.date ?? todayStr();
  const isToday = () => date() === todayStr();

  const [catalog] = createResource(() => api.catalog());
  const [record] = createResource(date, (d) => api.getRecord(d));

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
  const pct = () => (total() === 0 ? 0 : Math.round((completed().length / total()) * 100));

  const persist = async (next: string[], noteVal: string) => {
    try {
      await api.putRecord(date(), next, noteVal.trim() === "" ? null : noteVal);
      const t = new Date();
      setSavedAt(`${String(t.getHours()).padStart(2, "0")}:${String(t.getMinutes()).padStart(2, "0")} 저장됨`);
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

  const onNoteBlur = () => {
    void persist(completed(), note());
  };

  return (
    <div class="page dash">
      <header class="dash-head">
        <span class="eyebrow">{isToday() ? "오늘의 실천" : "지난 기록"}</span>
        <h2 class="dash-date">{date()}</h2>
        <Medallion pct={pct()} />
        <div class="dash-stat">
          <span class="big">{pct()}%</span>
          <span class="muted-line">
            {completed().length} / {total()} 항목 완료
          </span>
        </div>
      </header>

      <Show when={catalog()} fallback={<p class="muted-line">불러오는 중...</p>}>
        <Checklist items={catalog()!} completed={completed()} onToggle={toggle} />
      </Show>

      <label class="field note-field">
        <span>오늘의 메모</span>
        <textarea
          rows="3"
          value={note()}
          onInput={(e) => setNote(e.currentTarget.value)}
          onBlur={onNoteBlur}
          placeholder="좋았던 일, 떠오른 직감 등을 적어 두세요"
        />
      </label>
      <Show when={savedAt()}>
        <p class="save-hint">{savedAt()}</p>
      </Show>

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
    </div>
  );
}
