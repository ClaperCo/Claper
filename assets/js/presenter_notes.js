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
    const editorEl   = this.el.querySelector("#quill-editor-target");
    const placeholder = this.el.dataset.placeholder || "";

    // Let Quill CREATE its own toolbar from the options array.
    // The entire hook element has phx-update="ignore", so LiveView
    // will never touch the toolbar or editor DOM.
    this.quill = new Quill(editorEl, {
      theme: "snow",
      placeholder,
      modules: { toolbar: TOOLBAR_OPTIONS },
    });

    // Load initial content (set once via data attribute on first render).
    try {
      const initial = JSON.parse(this.el.dataset.initialContent || '""');
      if (initial) {
        this.quill.clipboard.dangerouslyPasteHTML(initial);
      }
    } catch (_e) { /* ignore parse errors */ }

    // Server pushes new content when the presenter navigates slides.
    this.handleEvent("load-note", ({ content }) => {
      this.quill.clipboard.dangerouslyPasteHTML(content || "");
    });

    // Auto-save: debounce 800 ms after the user stops typing.
    let timer;
    this.quill.on("text-change", (_delta, _old, source) => {
      if (source !== "user") return;
      clearTimeout(timer);
      timer = setTimeout(() => {
        const html    = this.el.querySelector(".ql-editor")?.innerHTML ?? EMPTY_HTML;
        const content = html === EMPTY_HTML ? "" : html;
        this.pushEvent("save-note", { content });
      }, 800);
    });
  },

  destroyed() {
    this.quill = null;
  },
};
