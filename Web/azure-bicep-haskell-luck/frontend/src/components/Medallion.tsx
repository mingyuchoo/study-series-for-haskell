import { type Component } from "solid-js";

/** 완료율(0~100)에 따라 금빛이 차오르는 運 도장. */
const Medallion: Component<{ pct: number }> = (props) => {
  return (
    <div class={`medallion ${props.pct >= 100 ? "complete" : ""}`}>
      <div class="medallion-fill" style={{ height: `${props.pct}%` }} />
      <div class="medallion-glyph">運</div>
    </div>
  );
};

export default Medallion;
