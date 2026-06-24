import {EditorView, ViewPlugin, Decoration, WidgetType, keymap} from "https://esm.sh/@codemirror/view@6.34.1";
import {EditorState, RangeSetBuilder} from "https://esm.sh/@codemirror/state@6.5.0";
import {history, historyKeymap, defaultKeymap, indentWithTab} from "https://esm.sh/@codemirror/commands@6.7.1";

const BULLETS = ["◉", "○", "✸", "✿"];
const COLORS = ["#BA7517", "#378ADD", "#D85A30", "#1D9E75", "#7F77DD"];
const ITEM = { "-": ["\u2022", "#378ADD"], "+": ["\u27A4", "#D85A30"] };

class Bullet extends WidgetType {
  constructor(level) { super(); this.level = level; }
  eq(other) { return other.level === this.level; }
  toDOM() {
    const s = document.createElement("span");
    s.className = "cm-orgbullet";
    s.textContent = BULLETS[(this.level - 1) % 4];
    s.style.color = COLORS[(this.level - 1) % 5];
    return s;
  }
  ignoreEvent() { return false; }
}

class ItemBullet extends WidgetType {
  constructor(ch) { super(); this.ch = ch; }
  eq(other) { return other.ch === this.ch; }
  toDOM() {
    const s = document.createElement("span");
    s.className = "cm-orgbullet";
    const conf = ITEM[this.ch];
    s.textContent = conf[0];
    s.style.color = conf[1];
    return s;
  }
  ignoreEvent() { return false; }
}

function buildDeco(view) {
  const b = new RangeSetBuilder();
  const sel = view.state.selection.main;
  for (const { from, to } of view.visibleRanges) {
    let pos = from;
    while (pos <= to) {
      const line = view.state.doc.lineAt(pos);
      const text = line.text;
      const h = /^(\*+)\s/.exec(text);
      if (h) {
        const level = h[1].length;
        b.add(line.from, line.from, Decoration.line({ class: "cm-org-h" + Math.min(level, 5) }));
        const cursorOnLine = sel.from <= line.to && sel.to >= line.from;
        if (!cursorOnLine) {
          b.add(line.from, line.from + level, Decoration.replace({ widget: new Bullet(level) }));
        }
      } else {
        const li = /^(\s*)([-+])\s/.exec(text);
        if (li) {
          b.add(line.from, line.from, Decoration.line({ class: "cm-org-li" }));
          const cursorOnLine = sel.from <= line.to && sel.to >= line.from;
          if (!cursorOnLine) {
            const markFrom = line.from + li[1].length;
            b.add(markFrom, markFrom + 1, Decoration.replace({ widget: new ItemBullet(li[2]) }));
          }
        } else if (/^\s*#\+/.test(text)) {
          b.add(line.from, line.from, Decoration.line({ class: "cm-org-kw" }));
        }
        const re = /(\*[^*\s][^*\n]*?\*)|(~[^~\n]+~)|(=[^=\n]+=)/g;
        let m;
        while ((m = re.exec(text))) {
          const s = line.from + m.index;
          const e = s + m[0].length;
          b.add(s, e, Decoration.mark({ class: m[1] ? "cm-org-b" : "cm-org-c" }));
        }
      }
      pos = line.to + 1;
    }
  }
  return b.finish();
}

const orgFontify = ViewPlugin.fromClass(
  class {
    constructor(view) { this.decorations = buildDeco(view); }
    update(u) {
      if (u.docChanged || u.viewportChanged || u.selectionSet) {
        this.decorations = buildDeco(u.view);
      }
    }
  },
  { decorations: (v) => v.decorations }
);

function init() {
  const mount = document.getElementById("org-editor");
  const textarea = document.getElementById("body");
  if (!mount || !textarea) return;

  const preview = document.getElementById("org-preview");
  let timer = null;
  const refresh = (doc) => {
    if (!preview) return;
    clearTimeout(timer);
    timer = setTimeout(async () => {
      try {
        const res = await fetch("/preview-fragment", {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: "body=" + encodeURIComponent(doc),
        });
        if (res.ok) preview.innerHTML = await res.text();
      } catch (_) { /* 미리보기 실패는 무시 */ }
    }, 250);
  };

  const sync = EditorView.updateListener.of((u) => {
    if (u.docChanged) {
      const doc = u.state.doc.toString();
      textarea.value = doc;
      refresh(doc);
    }
  });

  const view = new EditorView({
    doc: textarea.value,
    parent: mount,
    extensions: [
      history(),
      keymap.of([...defaultKeymap, ...historyKeymap, indentWithTab]),
      EditorView.lineWrapping,
      orgFontify,
      sync,
    ],
  });

  textarea.style.display = "none";
  mount.classList.add("ready");
  const form = textarea.closest("form");
  if (form) form.addEventListener("submit", () => { textarea.value = view.state.doc.toString(); });
  refresh(textarea.value);
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", init);
} else {
  init();
}

