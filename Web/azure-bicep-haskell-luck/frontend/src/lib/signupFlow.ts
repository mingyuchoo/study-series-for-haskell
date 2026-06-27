// 2단계 회원가입 흐름(정보 입력 → 인증번호 확인)의 상태/로직. 뷰(Signup)에서 분리해
// 재사용·테스트 가능하게 한다. 인증 성공 시 호출 측이 넘긴 onComplete 로 알린다.

import { createSignal, type Accessor } from "solid-js";
import { api } from "./api";
import { ApiError } from "./http";
import type { AuthResp } from "./types";

const msgOf = (ex: unknown, fallback: string): string =>
  ex instanceof ApiError ? ex.message : fallback;

export interface SignupFlow {
  displayName: Accessor<string>;
  setDisplayName: (v: string) => void;
  email: Accessor<string>;
  setEmail: (v: string) => void;
  password: Accessor<string>;
  setPassword: (v: string) => void;
  code: Accessor<string>;
  setCode: (v: string) => void;
  err: Accessor<string>;
  info: Accessor<string>;
  loading: Accessor<boolean>;
  step: Accessor<"form" | "verify">;
  requestCode: () => Promise<void>;
  verifyCode: () => Promise<void>;
  resend: () => Promise<void>;
  backToForm: () => void;
}

/** @param onComplete 가입+인증 성공 시 토큰/사용자를 전달받는다(로그인·이동은 호출 측 책임). */
export function createSignupFlow(onComplete: (resp: AuthResp) => void): SignupFlow {
  const [displayName, setDisplayName] = createSignal("");
  const [email, setEmail] = createSignal("");
  const [password, setPassword] = createSignal("");
  const [code, setCode] = createSignal("");
  const [err, setErr] = createSignal("");
  const [info, setInfo] = createSignal("");
  const [loading, setLoading] = createSignal(false);
  const [step, setStep] = createSignal<"form" | "verify">("form");

  // 1단계: 가입 정보 제출 → 인증번호 발급 요청
  const requestCode = async () => {
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
      setErr(msgOf(ex, "인증번호 발송에 실패했습니다."));
    } finally {
      setLoading(false);
    }
  };

  // 2단계: 인증번호 확인 → 가입 완료
  const verifyCode = async () => {
    setErr("");
    setLoading(true);
    try {
      const r = await api.auth.verifySignup(email().trim(), code().trim());
      onComplete(r);
    } catch (ex) {
      setErr(msgOf(ex, "인증번호 확인에 실패했습니다."));
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
      setErr(msgOf(ex, "인증번호 재발송에 실패했습니다."));
    } finally {
      setLoading(false);
    }
  };

  const backToForm = () => {
    setStep("form");
    setCode("");
    setErr("");
    setInfo("");
  };

  return {
    displayName,
    setDisplayName,
    email,
    setEmail,
    password,
    setPassword,
    code,
    setCode,
    err,
    info,
    loading,
    step,
    requestCode,
    verifyCode,
    resend,
    backToForm,
  };
}
