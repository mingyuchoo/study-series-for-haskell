import { createEffect, onMount, Show, type Component, type JSX } from "solid-js";
import { A, useNavigate, useLocation } from "@solidjs/router";
import { auth } from "../lib/store";
import ThemeToggle from "./ThemeToggle";

/** 인증된 사용자만 접근 가능한 공통 레이아웃. */
const Layout: Component<{ children?: JSX.Element }> = (props) => {
  const navigate = useNavigate();
  const location = useLocation();

  // 토큰이 없으면 로그인으로
  createEffect(() => {
    if (!auth.authed()) navigate("/login", { replace: true });
  });

  // 사용자 정보가 비어 있으면 한 번 하이드레이션한다(상세 로직은 store).
  onMount(() => void auth.ensureLoaded());

  const onLogout = async () => {
    await auth.signOut();
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
          <Show when={auth.user()?.isAdmin}>
            <A href="/admin" class={isActive("/admin")}>
              관리
            </A>
          </Show>
          <ThemeToggle />
          <button class="nav-logout" onClick={onLogout}>
            로그아웃
          </button>
        </div>
      </nav>
      <main class="content">
        {/* 인증된 경우에만 자식을 마운트한다. 미인증 상태에서 Dashboard 등이
            마운트돼 api/records 를 호출하면 401 이 새는 것을 막는다(리다이렉트는
            위 createEffect 가 담당). */}
        <Show when={auth.authed()}>{props.children}</Show>
      </main>
    </div>
  );
};

export default Layout;
