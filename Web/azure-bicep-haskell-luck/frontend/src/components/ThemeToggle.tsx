import type { Component } from "solid-js";
import { theme } from "../lib/theme";

/** 컬러 도트 테마 토글 — 클릭하면 7색을 순서대로 회전한다. */
const ThemeToggle: Component = () => {
  return (
    <button
      type="button"
      class="theme-toggle"
      aria-label="컬러 테마 변경"
      title={`테마: ${theme.current().label}`}
      onClick={() => theme.cycle()}
    >
      <span class="theme-toggle-dot" style={{ background: theme.current().color }} />
    </button>
  );
};

export default ThemeToggle;
