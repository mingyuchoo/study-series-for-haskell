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
  const [code, setCode] = createSignal("");
  const [err, setErr] = createSignal("");
  const [info, setInfo] = createSignal("");
  const [loading, setLoading] = createSignal(false);
  // "form" = 가입 정보 입력 단계, "verify" = 인증번호 입력 단계
  const [step, setStep] = createSignal<"form" | "verify">("form");

  // 1단계: 가입 정보 제출 → 인증번호 발급 요청
  const requestCode = async (e: Event) => {
    e.preventDefault();
    setErr("");
    if (password().length < 6) {
      setErr("비밀번호는 6자 이상이어야 합니다.");
      return;
    }
    setLoading(true);
    try {
      await api.auth.requestSignup(email().trim(), password(), displayName().trim());
      setStep("verify");
      setInfo("인증번호를 이메일로 발송했습니다. 메일함(스팸함 포함)을 확인하세요.");
    } catch (ex) {
      setErr(ex instanceof ApiError ? ex.message : "인증번호 발송에 실패했습니다.");
    } finally {
      setLoading(false);
    }
  };

  // 2단계: 인증번호 확인 → 가입 완료 후 로그인
  const verifyCode = async (e: Event) => {
    e.preventDefault();
    setErr("");
    setLoading(true);
    try {
      const r = await api.auth.verifySignup(email().trim(), code().trim());
      auth.login(r.token, r.user);
      navigate("/", { replace: true });
    } catch (ex) {
      setErr(ex instanceof ApiError ? ex.message : "인증번호 확인에 실패했습니다.");
    } finally {
      setLoading(false);
    }
  };

  // 인증번호 재발송 (가입 정보는 그대로 유지)
  const resend = async () => {
    setErr("");
    setInfo("");
    setLoading(true);
    try {
      await api.auth.requestSignup(email().trim(), password(), displayName().trim());
      setInfo("인증번호를 다시 발송했습니다. 메일함(스팸함 포함)을 확인하세요.");
    } catch (ex) {
      setErr(ex instanceof ApiError ? ex.message : "인증번호 재발송에 실패했습니다.");
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

        <Show when={step() === "form"}>
          <form onSubmit={requestCode}>
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
              {loading() ? "발송 중..." : "인증번호 받기"}
            </button>
          </form>
        </Show>

        <Show when={step() === "verify"}>
          <form onSubmit={verifyCode}>
            <p class="auth-sub">
              <strong>{email().trim()}</strong> 로 보낸 6자리 인증번호를 입력하세요.
            </p>
            <label class="field">
              <span>인증번호</span>
              <input
                type="text"
                inputMode="numeric"
                autocomplete="one-time-code"
                maxLength={6}
                value={code()}
                onInput={(e) => setCode(e.currentTarget.value)}
                placeholder="6자리 숫자"
                required
              />
            </label>
            <Show when={info()}>
              <p class="form-ok">{info()}</p>
            </Show>
            <Show when={err()}>
              <p class="form-error">{err()}</p>
            </Show>
            <button class="btn-primary" type="submit" disabled={loading()}>
              {loading() ? "확인 중..." : "회원가입 완료"}
            </button>
            <div class="auth-foot">
              <button type="button" class="link-btn" onClick={resend} disabled={loading()}>
                인증번호 재발송
              </button>
              {" · "}
              <button
                type="button"
                class="link-btn"
                onClick={() => {
                  setStep("form");
                  setCode("");
                  setErr("");
                  setInfo("");
                }}
                disabled={loading()}
              >
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
