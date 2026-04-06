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
    // LiveView updated the data-content attribute (slide changed).
    // Update Quill only if the content actually differs to avoid
    // disrupting the cursor while the user is actively typing.
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
    const editorEl = this.el.querySelector("[data-quill-editor]");
    const placeholder = this.el.dataset.placeholder || "";
    const initialContent = this.el.dataset.content || "";

    this.quill = new Quill(editorEl, {
      theme: "snow",
      placeholder,
      modules: { toolbar: TOOLBAR_OPTIONS },
    });

    // Load initial slide content
    if (initialContent) {
      this.quill.clipboard.dangerouslyPasteHTML(initialContent);
    }

    // Debounced save: push to LiveView 800 ms after the user stops typing
    let debounceTimer;
    this.quill.on("text-change", (_delta, _old, source) => {
      if (source !== "user") return;
      clearTimeout(debounceTimer);
      debounceTimer = setTimeout(() => {
        const html = this._getHtml();
        // Treat Quill's empty-document sentinel as an empty string
        const content = html === EMPTY_HTML ? "" : html;
        this.pushEvent("save-note", { content });
      }, 800);
    });
  },

  _getHtml() {
    return this.el.querySelector(".ql-editor")?.innerHTML ?? EMPTY_HTML;
  },
};
