// 인증 토큰의 로컬 영속화만 담당한다 (HTTP/상태와 분리).

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
