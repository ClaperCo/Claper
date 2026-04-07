import Quill from "quill";

const TOOLBAR_OPTIONS = [
  [{ header: [1, 2, 3, false] }],
  ["bold", "italic", "underline", "strike"],
  [{ color: [] }, { background: [] }],
  [{ list: "ordered" }, { list: "bullet" }],
  ["clean"],
];

// Quill's sentinel value for an empty document.
const EMPTY_HTML = "<p><br></p>";

export default {
  mounted() {
    // Remember which slide we're on so updated() can detect slide changes.
    this._position = this._readPosition();
    this._initQuill();
  },

  updated() {
    const newPosition = this._readPosition();

    if (newPosition !== this._position) {
      // Slide changed — load the new slide's note into the editor.
      this._position = newPosition;
      const incoming = this._readContent();
      this.quill.clipboard.dangerouslyPasteHTML(incoming || "");
    }
    // Same slide: the user may be actively typing. Never touch the editor
    // content here — the save is already in flight via pushEvent.
  },

  destroyed() {
    this.quill = null;
  },

  // ── private ───────────────────────────────────────────────────────────────

  _initQuill() {
    const toolbarEl       = this.el.querySelector("[data-quill-toolbar]");
    const editorEl        = this.el.querySelector("[data-quill-editor]");
    const placeholder     = this.el.dataset.placeholder || "";
    const initialContent  = this._readContent();

    this.quill = new Quill(editorEl, {
      theme: "snow",
      placeholder,
      modules: {
        // Point Quill at the pre-rendered container so the toolbar always
        // lives inside the phx-update="ignore" boundary.
        toolbar: { container: toolbarEl },
        // Quill 2.x ships with CMD/Ctrl+B/I/U/Z built-in — no overrides needed.
      },
    });

    if (initialContent) {
      this.quill.clipboard.dangerouslyPasteHTML(initialContent);
    }

    // Auto-save: debounce 800 ms after the user stops typing.
    let timer;
    this.quill.on("text-change", (_delta, _old, source) => {
      if (source !== "user") return;
      clearTimeout(timer);
      timer = setTimeout(() => {
        const html    = this._getEditorHtml();
        const content = html === EMPTY_HTML ? "" : html;
        this.pushEvent("save-note", { content });
      }, 800);
    });
  },

  // Current slide position from the hook element attribute.
  _readPosition() {
    return parseInt(this.el.dataset.position ?? "-1", 10);
  },

  // Read the note content from the JSON carrier <script> element.
  // <script type="application/json"> is never evaluated by the browser;
  // textContent returns the raw string without any entity decoding.
  _readContent() {
    const el = this.el.querySelector("#presenter-note-content");
    if (!el) return "";
    try {
      return JSON.parse(el.textContent.trim()) || "";
    } catch (_e) {
      return "";
    }
  },

  _getEditorHtml() {
    return this.el.querySelector(".ql-editor")?.innerHTML ?? EMPTY_HTML;
  },
};
