import { Show } from "solid-js";
import { A, useNavigate } from "@solidjs/router";
import { createSignupFlow } from "../lib/signupFlow";
import { auth } from "../lib/store";

export default function Signup() {
  const navigate = useNavigate();
  const f = createSignupFlow((r) => {
    auth.login(r.token, r.user);
    navigate("/", { replace: true });
  });

  const submit = (run: () => void) => (e: Event) => {
    e.preventDefault();
    run();
  };

  return (
    <div class="auth-wrap">
      <div class="auth-card">
        <div class="auth-mark">運</div>
        <h1 class="auth-title">운의 기록을 시작합니다</h1>
        <p class="auth-sub">매일 작게 채워 두는 행운의 장부.</p>

        <Show when={f.step() === "form"}>
          <form onSubmit={submit(f.requestCode)}>
            <label class="field">
              <span>이름</span>
              <input
                type="text"
                value={f.displayName()}
                onInput={(e) => f.setDisplayName(e.currentTarget.value)}
                placeholder="표시할 이름"
                required
              />
            </label>
            <label class="field">
              <span>이메일</span>
              <input
                type="email"
                value={f.email()}
                onInput={(e) => f.setEmail(e.currentTarget.value)}
                placeholder="you@example.com"
                required
              />
            </label>
            <label class="field">
              <span>비밀번호</span>
              <input
                type="password"
                value={f.password()}
                onInput={(e) => f.setPassword(e.currentTarget.value)}
                placeholder="6자 이상"
                required
              />
            </label>
            <Show when={f.err()}>
              <p class="form-error">{f.err()}</p>
            </Show>
            <button class="btn-primary" type="submit" disabled={f.loading()}>
              {f.loading() ? "발송 중..." : "인증번호 받기"}
            </button>
          </form>
        </Show>

        <Show when={f.step() === "verify"}>
          <form onSubmit={submit(f.verifyCode)}>
            <p class="auth-sub">
              <strong>{f.email().trim()}</strong> 로 보낸 6자리 인증번호를 입력하세요.
            </p>
            <label class="field">
              <span>인증번호</span>
              <input
                type="text"
                inputMode="numeric"
                autocomplete="one-time-code"
                maxLength={6}
                value={f.code()}
                onInput={(e) => f.setCode(e.currentTarget.value)}
                placeholder="6자리 숫자"
                required
              />
            </label>
            <Show when={f.info()}>
              <p class="form-ok">{f.info()}</p>
            </Show>
            <Show when={f.err()}>
              <p class="form-error">{f.err()}</p>
            </Show>
            <button class="btn-primary" type="submit" disabled={f.loading()}>
              {f.loading() ? "확인 중..." : "회원가입 완료"}
            </button>
            <div class="auth-foot">
              <button type="button" class="link-btn" onClick={f.resend} disabled={f.loading()}>
                인증번호 재발송
              </button>
              {" · "}
              <button type="button" class="link-btn" onClick={f.backToForm} disabled={f.loading()}>
                정보 수정
              </button>
            </div>
          </form>
        </Show>

        <p class="auth-foot">
          이미 계정이 있으신가요? <A href="/login">로그인</A>
        </p>
      </div>
    </div>
  );
}
