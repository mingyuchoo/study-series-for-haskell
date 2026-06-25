// 백엔드 API 클라이언트.

export interface UserDTO {
  id: string;
  email: string;
  displayName: string;
  bio: string;
  timezone: string;
  createdAt: string;
}

export interface AuthResp {
  token: string;
  user: UserDTO;
}

export interface CatalogItem {
  key: string;
  label: string;
}

export interface RecordDTO {
  date: string;
  completed: string[];
  note: string | null;
  total: number;
}

const TOKEN_KEY = "luck_token";

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}
export function setToken(t: string): void {
  localStorage.setItem(TOKEN_KEY, t);
}
export function clearToken(): void {
  localStorage.removeItem(TOKEN_KEY);
}

export class ApiError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

async function request<T>(path: string, opts: RequestInit = {}): Promise<T> {
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

export const api = {
  signup(email: string, password: string, displayName: string): Promise<AuthResp> {
    return request("/auth/signup", {
      method: "POST",
      body: JSON.stringify({ email, password, displayName }),
    });
  },
  login(email: string, password: string): Promise<AuthResp> {
    return request("/auth/login", {
      method: "POST",
      body: JSON.stringify({ email, password }),
    });
  },
  logout(): Promise<{ message: string }> {
    return request("/auth/logout", { method: "POST" });
  },
  catalog(): Promise<CatalogItem[]> {
    return request("/catalog");
  },
  me(): Promise<UserDTO> {
    return request("/me");
  },
  updateProfile(displayName: string, bio: string, timezone: string): Promise<UserDTO> {
    return request("/me", {
      method: "PUT",
      body: JSON.stringify({ displayName, bio, timezone }),
    });
  },
  getRecords(from: string, to: string): Promise<RecordDTO[]> {
    return request(`/records?from=${from}&to=${to}`);
  },
  getRecord(date: string): Promise<RecordDTO> {
    return request(`/records/${date}`);
  },
  putRecord(date: string, completed: string[], note: string | null): Promise<RecordDTO> {
    return request(`/records/${date}`, {
      method: "PUT",
      body: JSON.stringify({ completed, note }),
    });
  },
};
