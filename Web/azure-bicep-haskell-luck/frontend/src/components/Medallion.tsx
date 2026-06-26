import { type Component } from "solid-js";
import { isComplete } from "../lib/luck";

/** 완료율(0~100)에 따라 채워지는 運 도장. */
const Medallion: Component<{ pct: number }> = (props) => {
  return (
    <div class={`medallion ${isComplete(props.pct) ? "complete" : ""}`}>
      <div class="medallion-fill" style={{ height: `${props.pct}%` }} />
      <div class="medallion-glyph">運</div>
    </div>
  );
};

export default Medallion;
