import Quill from "quill";

const TOOLBAR_OPTIONS = [
  [{ header: [1, 2, 3, false] }],
  ["bold", "italic", "underline", "strike"],
  [{ color: [] }, { background: [] }],
  [{ list: "ordered" }, { list: "bullet" }],
  ["clean"],
];

const EMPTY_HTML = "<p><br></p>";

export default {
  mounted() {
    this._initQuill();
  },

  updated() {
    // LiveView updated data-content (slide changed).
    // Only update Quill when content actually differs to avoid
    // disrupting cursor position while the user is typing.
    const incoming = this.el.dataset.content || "";
    const current = this._getHtml();
    const normalised = incoming === "" ? EMPTY_HTML : incoming;

    if (current !== normalised) {
      this.quill.clipboard.dangerouslyPasteHTML(incoming);
    }
  },

  destroyed() {
    this.quill = null;
  },

  // ── private ───────────────────────────────────────────────────────────────

  _initQuill() {
    // Both toolbar and editor targets live inside the phx-update="ignore"
    // wrapper so LiveView never patches them away.
    const toolbarEl = this.el.querySelector("[data-quill-toolbar]");
    const editorEl = this.el.querySelector("[data-quill-editor]");
    const placeholder = this.el.dataset.placeholder || "";
    const initialContent = this.el.dataset.content || "";

    this.quill = new Quill(editorEl, {
      theme: "snow",
      placeholder,
      modules: {
        // Point Quill at our pre-rendered toolbar container so it is
        // always inside phx-update="ignore" and LiveView never removes it.
        toolbar: { container: toolbarEl },

        // Explicit keyboard shortcuts (CMD/Ctrl + key).
        keyboard: {
          bindings: {
            bold:      { key: "B", shortKey: true, handler() { this.quill.format("bold",      !this.quill.getFormat().bold);      } },
            italic:    { key: "I", shortKey: true, handler() { this.quill.format("italic",    !this.quill.getFormat().italic);    } },
            underline: { key: "U", shortKey: true, handler() { this.quill.format("underline", !this.quill.getFormat().underline); } },
            strike:    { key: "D", shortKey: true, handler() { this.quill.format("strike",    !this.quill.getFormat().strike);    } },
          },
        },
      },
    });

    // Load initial slide content.
    if (initialContent) {
      this.quill.clipboard.dangerouslyPasteHTML(initialContent);
    }

    // Debounced auto-save: push to LiveView 800 ms after the user stops typing.
    let debounceTimer;
    this.quill.on("text-change", (_delta, _old, source) => {
      if (source !== "user") return;
      clearTimeout(debounceTimer);
      debounceTimer = setTimeout(() => {
        const html = this._getHtml();
        const content = html === EMPTY_HTML ? "" : html;
        this.pushEvent("save-note", { content });
      }, 800);
    });
  },

  _getHtml() {
    return this.el.querySelector(".ql-editor")?.innerHTML ?? EMPTY_HTML;
  },
};
