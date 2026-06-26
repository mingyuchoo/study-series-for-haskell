// 백엔드 엔드포인트 정의 (기능별 네임스페이스). 트랜스포트는 http.ts, 타입은 types.ts.

import { request } from "./http";
import type { AdminCatalogItem, AuthResp, CatalogItem, RecordDTO, UserDTO } from "./types";

/** 인증 (회원가입/로그인/로그아웃). */
const authApi = {
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
};

/** 내 프로필 조회/수정. */
const profileApi = {
  me(): Promise<UserDTO> {
    return request("/me");
  },
  update(displayName: string, bio: string, timezone: string): Promise<UserDTO> {
    return request("/me", {
      method: "PUT",
      body: JSON.stringify({ displayName, bio, timezone }),
    });
  },
};

/** 일별 기록 조회/저장. */
const recordsApi = {
  list(from: string, to: string): Promise<RecordDTO[]> {
    return request(`/records?from=${from}&to=${to}`);
  },
  get(date: string): Promise<RecordDTO> {
    return request(`/records/${date}`);
  },
  save(date: string, completed: string[], note: string | null): Promise<RecordDTO> {
    return request(`/records/${date}`, {
      method: "PUT",
      body: JSON.stringify({ completed, note }),
    });
  },
};

/** 공개 카탈로그 (활성 항목만). */
const catalogApi = {
  list(): Promise<CatalogItem[]> {
    return request("/catalog");
  },
};

/** 관리자 전용 카탈로그 CRUD (목록은 비활성 항목까지 포함). */
const adminApi = {
  list(): Promise<AdminCatalogItem[]> {
    return request("/admin/catalog");
  },
  create(label: string): Promise<AdminCatalogItem> {
    return request("/admin/catalog", {
      method: "POST",
      body: JSON.stringify({ label }),
    });
  },
  update(key: string, label: string): Promise<AdminCatalogItem> {
    return request(`/admin/catalog/${encodeURIComponent(key)}`, {
      method: "PUT",
      body: JSON.stringify({ label }),
    });
  },
  setActive(key: string, active: boolean): Promise<AdminCatalogItem> {
    return request(`/admin/catalog/${encodeURIComponent(key)}/active`, {
      method: "PUT",
      body: JSON.stringify({ active }),
    });
  },
  remove(key: string): Promise<{ message: string }> {
    return request(`/admin/catalog/${encodeURIComponent(key)}`, {
      method: "DELETE",
    });
  },
};

export const api = {
  auth: authApi,
  profile: profileApi,
  records: recordsApi,
  catalog: catalogApi,
  admin: adminApi,
};
