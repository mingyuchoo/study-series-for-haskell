import { createSignal, onMount, Show, type Component, type JSX } from "solid-js";
import { useNavigate } from "@solidjs/router";
import { api } from "../lib/api";
import { auth } from "../lib/store";

/**
 * 관리자만 접근 가능한 라우트 가드. 인가를 페이지 본문에서 분리해 중앙화한다.
 * (권한은 항상 서버가 강제하며, 이건 UI 차원의 방어 + 비관리자 리다이렉트.)
 */
const RequireAdmin: Component<{ children?: JSX.Element }> = (props) => {
  const navigate = useNavigate();
  const [ready, setReady] = createSignal(false);

  onMount(async () => {
    let u = auth.user();
    if (!u) {
      try {
        u = await api.profile.me();
        auth.setUser(u);
      } catch {
        // 401 등은 http 계층이 처리 (전역 로그아웃)
        return;
      }
    }
    if (!u.isAdmin) {
      navigate("/", { replace: true });
      return;
    }
    setReady(true);
  });

  return (
    <Show when={ready()} fallback={<p class="muted-line">권한 확인 중...</p>}>
      {props.children}
    </Show>
  );
};

export default RequireAdmin;
