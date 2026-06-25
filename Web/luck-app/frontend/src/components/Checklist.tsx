import { For, type Component } from "solid-js";
import { type CatalogItem } from "../lib/api";

interface Props {
  items: CatalogItem[];
  completed: string[];
  onToggle: (key: string) => void;
}

/** 항목을 눌러 완료/미완료를 토글하는 체크리스트. */
const Checklist: Component<Props> = (props) => {
  const isDone = (key: string) => props.completed.includes(key);

  return (
    <div class="list">
      <For each={props.items}>
        {(item) => (
          <div
            class={`item ${isDone(item.key) ? "done" : ""}`}
            role="checkbox"
            tabindex="0"
            aria-checked={isDone(item.key)}
            onClick={() => props.onToggle(item.key)}
            onKeyDown={(e) => {
              if (e.key === " " || e.key === "Enter") {
                e.preventDefault();
                props.onToggle(item.key);
              }
            }}
          >
            <span class="box" />
            <span class="txt">{item.label}</span>
          </div>
        )}
      </For>
    </div>
  );
};

export default Checklist;
