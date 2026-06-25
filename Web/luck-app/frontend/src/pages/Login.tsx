import { createSignal, Show } from "solid-js";
import { A, useNavigate } from "@solidjs/router";
import { api, ApiError } from "../lib/api";
import { auth } from "../lib/store";

export default function Login() {
  const navigate = useNavigate();
  const [email, setEmail] = createSignal("");
  const [password, setPassword] = createSignal("");
  const [err, setErr] = createSignal("");
  const [loading, setLoading] = createSignal(false);

  const submit = async (e: Event) => {
    e.preventDefault();
    setErr("");
    setLoading(true);
    try {
      const r = await api.login(email().trim(), password());
      auth.login(r.token, r.user);
      navigate("/", { replace: true });
    } catch (ex) {
      setErr(ex instanceof ApiError ? ex.message : "로그인에 실패했습니다.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div class="auth-wrap">
      <div class="auth-card">
        <div class="auth-mark">運</div>
        <h1 class="auth-title">다시 오신 걸 환영합니다</h1>
        <p class="auth-sub">오늘의 운을 이어서 채워 보세요.</p>
        <form onSubmit={submit}>
          <label class="field">
            <span>이메일</span>
            <input
              type="email"
              value={email()}
              onInput={(e) => setEmail(e.currentTarget.value)}
              placeholder="you@example.com"
              required
            />
          </label>
          <label class="field">
            <span>비밀번호</span>
            <input
              type="password"
              value={password()}
              onInput={(e) => setPassword(e.currentTarget.value)}
              placeholder="비밀번호"
              required
            />
          </label>
          <Show when={err()}>
            <p class="form-error">{err()}</p>
          </Show>
          <button class="btn-primary" type="submit" disabled={loading()}>
            {loading() ? "확인 중..." : "로그인"}
          </button>
        </form>
        <p class="auth-foot">
          아직 계정이 없으신가요? <A href="/signup">회원가입</A>
        </p>
      </div>
    </div>
  );
}
