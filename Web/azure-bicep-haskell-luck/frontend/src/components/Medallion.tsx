import { type Component } from "solid-js";
import { isComplete } from "../lib/luck";

/** 완료율(0~100)에 따라 채워지는 運 도장. */
const Medallion: Component<{ pct: number }> = (props) => {
  return (
    <div class={`medallion ${isComplete(props.pct) ? "complete" : ""}`}>
      {/* 빈 트랙 위 글자 (검정) */}
      <div class="medallion-glyph">運</div>
      {/* 채움 영역 — 그 안의 흰 글자는 수면 아래(채움)만큼만 보인다 */}
      <div class="medallion-fill" style={{ height: `${props.pct}%` }}>
        <div class="medallion-glyph medallion-glyph-fill">運</div>
      </div>
    </div>
  );
};

export default Medallion;
