// 전역 인증 상태 (Solid 시그널) + 인증 수명주기(하이드레이션/로그아웃).

import { createSignal } from "solid-js";
import { api } from "./api";
import { theme } from "./theme";
import { clearToken, getToken, setToken } from "./token";
import type { UserDTO } from "./types";

const [user, setUserSignal] = createSignal<UserDTO | null>(null);
const [authed, setAuthed] = createSignal<boolean>(!!getToken());

export const auth = {
  user,
  authed,
  login(token: string, u: UserDTO): void {
    setToken(token);
    setUserSignal(u);
    setAuthed(true);
    theme.setByKey(u.themeKey);
  },
  setUser(u: UserDTO): void {
    setUserSignal(u);
  },
  logout(): void {
    clearToken();
    setUserSignal(null);
    setAuthed(false);
  },
  // 새로고침 등으로 사용자 정보가 비어 있으면 한 번 불러온다(관리 메뉴 노출 판단용).
  // 실패 시 401 처리는 http 계층이 담당하므로 여기서는 무시한다.
  async ensureLoaded(): Promise<void> {
    if (authed() && !user()) {
      try {
        const u = await api.profile.me();
        setUserSignal(u);
        theme.setByKey(u.themeKey);
      } catch {
        // 무시
      }
    }
  },
  // 서버 세션 종료를 시도한 뒤 로컬 토큰/상태를 정리한다.
  // 로그아웃의 본질은 클라이언트 토큰 삭제이므로 서버 실패는 무시한다.
  async signOut(): Promise<void> {
    try {
      await api.auth.logout();
    } catch {
      // 무시
    }
    auth.logout();
  },
};
