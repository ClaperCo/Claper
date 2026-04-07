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
    this._initQuill();
  },

  updated() {
    // LiveView updated the <script> content carrier (slide changed).
    // Only push to Quill when the content actually differs so we don't
    // disrupt the cursor while the user is actively typing.
    const incoming = this._readContent();
    const current  = this._getEditorHtml();

    if (current !== (incoming || EMPTY_HTML)) {
      this.quill.clipboard.dangerouslyPasteHTML(incoming || "");
    }
  },

  destroyed() {
    this.quill = null;
  },

  // ── private ───────────────────────────────────────────────────────────────

  _initQuill() {
    const toolbarEl    = this.el.querySelector("[data-quill-toolbar]");
    const editorEl     = this.el.querySelector("[data-quill-editor]");
    const placeholder  = this.el.dataset.placeholder || "";
    const initialContent = this._readContent();

    this.quill = new Quill(editorEl, {
      theme: "snow",
      placeholder,
      modules: {
        // Point Quill at the pre-rendered container so the toolbar always
        // lives inside the phx-update="ignore" boundary.
        toolbar: { container: toolbarEl },
        // Quill 2.x ships with CMD/Ctrl + B/I/U/Z built-in.
        // No need to override; adding custom bindings here would break them.
      },
    });

    // Populate editor with the current slide's note.
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

  // Read the note content from the JSON carrier <script> element.
  // Using a <script type="application/json"> avoids all HTML-attribute
  // encoding issues — the browser never evaluates it and textContent
  // returns the raw string without any entity decoding.
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
