// HTTP 트랜스포트: 토큰 부착, 에러 정규화, 401 처리. 엔드포인트 정의는 api.ts.

import { clearToken, getToken } from "./token";

export class ApiError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

export async function request<T>(path: string, opts: RequestInit = {}): Promise<T> {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    ...((opts.headers as Record<string, string>) ?? {}),
  };
  const token = getToken();
  if (token) headers["Authorization"] = `Bearer ${token}`;

  const res = await fetch("/api" + path, { ...opts, headers });

  if (res.status === 401) {
    clearToken();
    window.dispatchEvent(new CustomEvent("luck:unauthorized"));
    throw new ApiError(401, "인증이 필요합니다.");
  }

  if (!res.ok) {
    let msg = `요청 실패 (${res.status})`;
    try {
      const body = await res.json();
      if (body && typeof body.message === "string") msg = body.message;
    } catch {
      // JSON 아님 — 기본 메시지 유지
    }
    throw new ApiError(res.status, msg);
  }

  if (res.status === 204) return undefined as T;
  return (await res.json()) as T;
}
