// 컬러 테마 토글 상태. 이미지의 7개 색(섹션 배경 토큰)을 회전시킨다.
// 선택 색은 --theme-ground/--theme-ink CSS 변수로 노출되고(나머지 색은 color-mix 파생),
// localStorage 에 저장된다.

import { createSignal } from "solid-js";

export interface Theme {
  key: string;
  label: string;
  /** 시그니처 배경색. styles.css 의 --block-* 토큰을 가리킨다. */
  color: string;
  /** 배경 위 글씨색. 파스텔은 검정, 어두운 네이비는 밝은색. */
  ink: string;
}

const DARK_INK = "#1a1a1a";
const LIGHT_INK = "#f5f5f3";

export const THEMES: Theme[] = [
  { key: "lime", label: "라임", color: "var(--block-lime)", ink: DARK_INK },
  { key: "lilac", label: "라일락", color: "var(--block-lilac)", ink: DARK_INK },
  { key: "navy", label: "네이비", color: "var(--block-navy)", ink: LIGHT_INK },
  { key: "cream", label: "크림", color: "var(--block-cream)", ink: DARK_INK },
  { key: "mint", label: "민트", color: "var(--block-mint)", ink: DARK_INK },
  { key: "pink", label: "핑크", color: "var(--block-pink)", ink: DARK_INK },
  { key: "coral", label: "코랄", color: "var(--block-coral)", ink: DARK_INK },
];

const STORAGE_KEY = "luck_theme";

function loadIndex(): number {
  const raw = localStorage.getItem(STORAGE_KEY);
  const n = raw === null ? 0 : Number(raw);
  return Number.isInteger(n) && n >= 0 && n < THEMES.length ? n : 0;
}

const [index, setIndex] = createSignal(loadIndex());

function apply(i: number): void {
  const t = THEMES[i];
  const root = document.documentElement;
  // 단일 소스: 배경/글씨색만 세팅하면 heatmap 램프는 CSS color-mix 가 파생한다.
  root.style.setProperty("--theme-ground", t.color);
  root.style.setProperty("--theme-ink", t.ink);
  root.setAttribute("data-theme", t.key);
}

export const theme = {
  /** 현재 테마. */
  current: () => THEMES[index()],
  index,
  /** 다음 색으로 회전(7개 순환) + 저장 + 적용. */
  cycle(): void {
    const next = (index() + 1) % THEMES.length;
    setIndex(next);
    localStorage.setItem(STORAGE_KEY, String(next));
    apply(next);
  },
  /** 저장된 테마를 DOM에 반영 (앱 시작 시 1회 호출). */
  init(): void {
    apply(index());
  },
};
