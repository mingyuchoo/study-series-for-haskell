// 한글 IME 입력 헬퍼. 조합(composition) 중 값 역기입으로 글자가 떨리는 것을 막는다.
// 여러 입력 컴포넌트(Dashboard 메모, Admin 라벨 등)에서 공유한다.

import type { JSX } from "solid-js";

type TextEl = HTMLInputElement | HTMLTextAreaElement;

/**
 * 값 setter를 받아 IME-안전한 입력 핸들러 묶음을 돌려준다.
 * 사용: <input {...imeInput(setValue)} />
 */
export function imeInput(setValue: (v: string) => void): {
  onInput: JSX.EventHandler<TextEl, InputEvent>;
  onCompositionEnd: JSX.EventHandler<TextEl, CompositionEvent>;
} {
  return {
    onInput: (e) => {
      // 조합 중에는 무시하고, onCompositionEnd 에서 확정값을 반영한다.
      if (e.isComposing) return;
      setValue(e.currentTarget.value);
    },
    onCompositionEnd: (e) => {
      setValue(e.currentTarget.value);
    },
  };
}
