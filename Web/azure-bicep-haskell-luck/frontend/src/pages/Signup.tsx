import { createSignal, Show } from "solid-js";
import { A, useNavigate } from "@solidjs/router";
import { api } from "../lib/api";
import { ApiError } from "../lib/http";
import { auth } from "../lib/store";

export default function Signup() {
  const navigate = useNavigate();
  const [displayName, setDisplayName] = createSignal("");
  const [email, setEmail] = createSignal("");
  const [password, setPassword] = createSignal("");
  const [err, setErr] = createSignal("");
  const [loading, setLoading] = createSignal(false);

  const submit = async (e: Event) => {
    e.preventDefault();
    setErr("");
    if (password().length < 6) {
      setErr("비밀번호는 6자 이상이어야 합니다.");
      return;
    }
    setLoading(true);
    try {
      const r = await api.auth.signup(email().trim(), password(), displayName().trim());
      auth.login(r.token, r.user);
      navigate("/", { replace: true });
    } catch (ex) {
      setErr(ex instanceof ApiError ? ex.message : "회원가입에 실패했습니다.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div class="auth-wrap">
      <div class="auth-card">
        <div class="auth-mark">運</div>
        <h1 class="auth-title">운의 기록을 시작합니다</h1>
        <p class="auth-sub">매일 작게 채워 두는 행운의 장부.</p>
        <form onSubmit={submit}>
          <label class="field">
            <span>이름</span>
            <input
              type="text"
              value={displayName()}
              onInput={(e) => setDisplayName(e.currentTarget.value)}
              placeholder="표시할 이름"
              required
            />
          </label>
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
              placeholder="6자 이상"
              required
            />
          </label>
          <Show when={err()}>
            <p class="form-error">{err()}</p>
          </Show>
          <button class="btn-primary" type="submit" disabled={loading()}>
            {loading() ? "가입 중..." : "회원가입"}
          </button>
        </form>
        <p class="auth-foot">
          이미 계정이 있으신가요? <A href="/login">로그인</A>
        </p>
      </div>
    </div>
  );
}
