// 전역 인증 상태 (Solid 시그널).

import { createSignal } from "solid-js";
import { clearToken, getToken, setToken, type UserDTO } from "./api";

const [user, setUserSignal] = createSignal<UserDTO | null>(null);
const [authed, setAuthed] = createSignal<boolean>(!!getToken());

export const auth = {
  user,
  authed,
  login(token: string, u: UserDTO): void {
    setToken(token);
    setUserSignal(u);
    setAuthed(true);
  },
  setUser(u: UserDTO): void {
    setUserSignal(u);
  },
  logout(): void {
    clearToken();
    setUserSignal(null);
    setAuthed(false);
  },
};
