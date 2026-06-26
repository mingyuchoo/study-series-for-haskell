// 백엔드 엔드포인트 정의. 트랜스포트는 http.ts, 타입은 types.ts, 토큰은 token.ts.

import { request } from "./http";
import type { AuthResp, CatalogItem, RecordDTO, UserDTO } from "./types";

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

  // 관리자 전용: 체크리스트 항목 CRUD
  // 목록은 비활성 항목까지 포함 (공개 catalog() 는 활성 항목만 준다)
  adminCatalog(): Promise<CatalogItem[]> {
    return request("/admin/catalog");
  },
  createCatalogItem(label: string): Promise<CatalogItem> {
    return request("/admin/catalog", {
      method: "POST",
      body: JSON.stringify({ label }),
    });
  },
  updateCatalogItem(key: string, label: string): Promise<CatalogItem> {
    return request(`/admin/catalog/${encodeURIComponent(key)}`, {
      method: "PUT",
      body: JSON.stringify({ label }),
    });
  },
  setCatalogItemActive(key: string, active: boolean): Promise<CatalogItem> {
    return request(`/admin/catalog/${encodeURIComponent(key)}/active`, {
      method: "PUT",
      body: JSON.stringify({ active }),
    });
  },
  deleteCatalogItem(key: string): Promise<{ message: string }> {
    return request(`/admin/catalog/${encodeURIComponent(key)}`, {
      method: "DELETE",
    });
  },
};
