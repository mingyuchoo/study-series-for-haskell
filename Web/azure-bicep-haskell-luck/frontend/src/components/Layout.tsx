import { createEffect, type Component, type JSX } from "solid-js";
import { A, useNavigate, useLocation } from "@solidjs/router";
import { auth } from "../lib/store";
import { api } from "../lib/api";

/** 인증된 사용자만 접근 가능한 공통 레이아웃. */
const Layout: Component<{ children?: JSX.Element }> = (props) => {
  const navigate = useNavigate();
  const location = useLocation();

  // 토큰이 없으면 로그인으로
  createEffect(() => {
    if (!auth.authed()) navigate("/login", { replace: true });
  });

  const onLogout = async () => {
    try {
      await api.logout();
    } catch {
      // 로그아웃은 클라이언트 토큰 삭제가 본질 — 실패 무시
    }
    auth.logout();
    navigate("/login", { replace: true });
  };

  const isActive = (path: string) => (location.pathname === path ? "nav-link active" : "nav-link");

  return (
    <div class="shell">
      <nav class="topnav">
        <A href="/" class="brand">
          運
        </A>
        <div class="nav-links">
          <A href="/" class={isActive("/")} end>
            오늘
          </A>
          <A href="/calendar" class={isActive("/calendar")}>
            달력
          </A>
          <A href="/profile" class={isActive("/profile")}>
            프로필
          </A>
          <button class="nav-logout" onClick={onLogout}>
            로그아웃
          </button>
        </div>
      </nav>
      <main class="content">{props.children}</main>
    </div>
  );
};

export default Layout;
