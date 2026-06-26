import { createSignal, onMount, Show } from "solid-js";
import { api } from "../lib/api";
import { ApiError } from "../lib/http";
import { auth } from "../lib/store";

const TIMEZONES = [
  "Asia/Seoul",
  "Asia/Tokyo",
  "Asia/Shanghai",
  "America/New_York",
  "America/Los_Angeles",
  "Europe/London",
  "UTC",
];

export default function Profile() {
  const [displayName, setDisplayName] = createSignal("");
  const [bio, setBio] = createSignal("");
  const [timezone, setTimezone] = createSignal("Asia/Seoul");
  const [email, setEmail] = createSignal("");
  const [loading, setLoading] = createSignal(true);
  const [saving, setSaving] = createSignal(false);
  const [msg, setMsg] = createSignal("");
  const [err, setErr] = createSignal("");

  onMount(async () => {
    try {
      const u = await api.me();
      setEmail(u.email);
      setDisplayName(u.displayName);
      setBio(u.bio);
      setTimezone(u.timezone);
      auth.setUser(u);
    } catch (ex) {
      setErr(ex instanceof ApiError ? ex.message : "프로필을 불러오지 못했습니다.");
    } finally {
      setLoading(false);
    }
  });

  const save = async (e: Event) => {
    e.preventDefault();
    setMsg("");
    setErr("");
    setSaving(true);
    try {
      const u = await api.updateProfile(displayName().trim(), bio(), timezone());
      auth.setUser(u);
      setMsg("저장되었습니다.");
    } catch (ex) {
      setErr(ex instanceof ApiError ? ex.message : "저장에 실패했습니다.");
    } finally {
      setSaving(false);
    }
  };

  return (
    <div class="page">
      <header class="page-head">
        <span class="eyebrow">設定</span>
        <h2>프로필 설정</h2>
      </header>

      <Show when={!loading()} fallback={<p class="muted-line">불러오는 중...</p>}>
        <form class="card-form" onSubmit={save}>
          <label class="field">
            <span>이메일 (변경 불가)</span>
            <input type="email" value={email()} disabled />
          </label>
          <label class="field">
            <span>이름</span>
            <input
              type="text"
              value={displayName()}
              onInput={(e) => setDisplayName(e.currentTarget.value)}
              required
            />
          </label>
          <label class="field">
            <span>소개</span>
            <textarea
              rows="3"
              value={bio()}
              onInput={(e) => setBio(e.currentTarget.value)}
              placeholder="짧은 소개 (선택)"
            />
          </label>
          <label class="field">
            <span>시간대</span>
            <select
              value={timezone()}
              onChange={(e) => setTimezone(e.currentTarget.value)}
            >
              {TIMEZONES.map((tz) => (
                <option value={tz}>{tz}</option>
              ))}
            </select>
          </label>

          <Show when={err()}>
            <p class="form-error">{err()}</p>
          </Show>
          <Show when={msg()}>
            <p class="form-ok">{msg()}</p>
          </Show>

          <button class="btn-primary" type="submit" disabled={saving()}>
            {saving() ? "저장 중..." : "변경 사항 저장"}
          </button>
        </form>
      </Show>
    </div>
  );
}
