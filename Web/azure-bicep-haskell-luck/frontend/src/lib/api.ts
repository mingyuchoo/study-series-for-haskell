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
};
