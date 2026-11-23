// Virtual pointer.
//
// The presenter moves the mouse over the slide preview in the manage view and
// the position is mirrored as a laser-pointer dot on the projected
// presentation and on the attendees' devices.
//
// Positions are normalized (0..1) relative to the slide image itself, not to
// its container, so they line up on every screen whatever size, aspect ratio
// or letterboxing it renders the slide with.

const SEND_INTERVAL_MS = 40;
// While the pointer rests on the slide it is re-sent now and then, so that
// receivers can safely drop a pointer that has gone silent (closed tab, lost
// connection) instead of leaving it stuck on screen.
const KEEPALIVE_MS = 2000;
const HIDE_AFTER_MS = 6000;
const CURSOR_HIDDEN_CLASS = "pointer-cursor-hidden";

// Rectangle (in viewport coordinates) that the slide picture really covers,
// which for `object-fit: contain` is smaller than the <img> box.
export function slideRect(img) {
  const box = img.getBoundingClientRect();
  const naturalWidth = img.naturalWidth;
  const naturalHeight = img.naturalHeight;

  if (!naturalWidth || !naturalHeight || !box.width || !box.height) {
    return box;
  }

  const scale = Math.min(box.width / naturalWidth, box.height / naturalHeight);
  const width = naturalWidth * scale;
  const height = naturalHeight * scale;

  return {
    left: box.left + (box.width - width) / 2,
    top: box.top + (box.height - height) / 2,
    width,
    height,
  };
}

const round = (value) => Math.round(value * 10000) / 10000;

// Owns the on/off toggle (button and "L" shortcut) and sends the pointer
// position to the server. Used in the manage view (mouse over the slide
// preview) and in the presenter window (mouse over the slide itself).
//
// The presenter sees the same dot the audience sees, drawn right under the
// mouse (no round trip to the server). The system cursor is hidden only while
// the mouse is over the slide, so it is still there everywhere else.
//
// options:
//   target            element that receives the mouse events (default: the hook element)
//   leaveTarget       element whose "pointerleave" hides the pointer (default: the hook element)
//   findImage         () => the slide <img> the mouse position is measured against
//   findHost          () => the positioned element that contains the local dot
//                     ([data-pointer-dot]); the dot is placed relative to it
//   findCursorTarget  () => the element whose cursor is hidden over the slide
export class PointerSender {
  constructor(context, options = {}) {
    this.context = context;
    this.el = context.el;
    this.target = options.target || this.el;
    this.leaveTarget = options.leaveTarget || this.el;
    this.findImage =
      options.findImage || (() => this.el.querySelector("[data-pointer-image]"));
    this.findHost =
      options.findHost || (() => this.el.querySelector("[data-pointer-host]"));
    this.findCursorTarget =
      options.findCursorTarget ||
      (() => this.el.querySelector("[data-pointer-surface]"));
    this.localVisible = false;
    this.enabled = false;
    this.visible = false;
    this.last = null;
    this.lastSentAt = -Infinity;
    this.trailingTimer = null;
    this.keepAliveTimer = null;
    this.position = this.el.dataset.position;
  }

  init() {
    this.onClick = (e) => {
      if (e.target.closest("[data-pointer-toggle]")) this.toggle();
    };
    this.onMove = (e) => this.move(e);
    this.onLeave = () => this.hide();
    this.onKey = (e) => this.key(e);

    this.el.addEventListener("click", this.onClick);
    this.target.addEventListener("pointermove", this.onMove);
    this.leaveTarget.addEventListener("pointerleave", this.onLeave);
    window.addEventListener("keydown", this.onKey);

    this.sync();
  }

  update() {
    // The slide changed: the pointer is gone until the mouse moves again.
    if (this.position !== this.el.dataset.position) {
      this.position = this.el.dataset.position;
      this.hide();
    }

    // LiveView re-renders reset the attributes this class sets.
    this.sync();
  }

  destroy() {
    this.el.removeEventListener("click", this.onClick);
    this.target.removeEventListener("pointermove", this.onMove);
    this.leaveTarget.removeEventListener("pointerleave", this.onLeave);
    window.removeEventListener("keydown", this.onKey);
    this.clearTimers();
    this.hideLocal();
  }

  // The server already told everyone to hide the pointer (slide change):
  // forget it locally without announcing anything.
  reset() {
    this.clearTimers();
    this.last = null;
    this.visible = false;
    this.hideLocal();
  }

  toggle() {
    this.enabled = !this.enabled;
    if (!this.enabled) this.hide();
    this.sync();
  }

  key(e) {
    if (e.defaultPrevented || e.repeat) return;
    if (e.ctrlKey || e.metaKey || e.altKey) return;
    if (e.key !== "l" && e.key !== "L") return;

    const target = e.target;
    const tag = (target.tagName || "").toLowerCase();
    if (target.isContentEditable) return;
    if (tag === "input" || tag === "textarea" || tag === "select") return;

    e.preventDefault();
    this.toggle();
  }

  sync() {
    const button = this.el.querySelector("[data-pointer-toggle]");
    if (button) button.setAttribute("aria-pressed", String(this.enabled));

    const surface = this.el.querySelector("[data-pointer-surface]");
    if (surface) surface.style.touchAction = this.enabled ? "none" : "";

    this.applyCursor();
  }

  applyCursor() {
    const target = this.findCursorTarget();
    if (!target) return;

    // A class (with !important in app.css) instead of an inline style, so
    // that elements with a cursor of their own cannot bring the cursor back.
    if (this.localVisible) target.classList.add(CURSOR_HIDDEN_CLASS);
    else target.classList.remove(CURSOR_HIDDEN_CLASS);
  }

  // Draws the dot under the mouse, the way the audience sees it.
  showLocal(x, y, rect) {
    const host = this.findHost();
    const dot = host && host.querySelector("[data-pointer-dot]");
    if (!dot) return;

    const hostRect = host.getBoundingClientRect();
    dot.style.transition = "none";
    dot.style.left = `${rect.left - hostRect.left + x * rect.width}px`;
    dot.style.top = `${rect.top - hostRect.top + y * rect.height}px`;
    dot.classList.remove("hidden");

    this.localVisible = true;
    this.applyCursor();
  }

  hideLocal() {
    const host = this.findHost();
    const dot = host && host.querySelector("[data-pointer-dot]");
    if (dot) dot.classList.add("hidden");

    this.localVisible = false;
    this.applyCursor();
  }

  move(e) {
    if (!this.enabled) return;

    const img = this.findImage();
    if (!img) {
      // No slide on screen (e.g. an embed is shown).
      this.hide();
      return;
    }

    const rect = slideRect(img);
    if (!rect.width || !rect.height) return;

    const x = (e.clientX - rect.left) / rect.width;
    const y = (e.clientY - rect.top) / rect.height;

    if (x < 0 || x > 1 || y < 0 || y > 1) {
      this.hide();
      return;
    }

    this.last = { x, y };
    this.showLocal(x, y, rect);
    this.schedule();
  }

  // Sends at most one position per SEND_INTERVAL_MS, always ending on the
  // latest one.
  schedule() {
    const wait = SEND_INTERVAL_MS - (performance.now() - this.lastSentAt);

    if (wait <= 0) {
      this.flush();
    } else if (!this.trailingTimer) {
      this.trailingTimer = setTimeout(() => {
        this.trailingTimer = null;
        this.flush();
      }, wait);
    }
  }

  flush() {
    if (!this.last) return;

    this.lastSentAt = performance.now();
    this.visible = true;
    this.context.pushEvent("pointer-move", {
      x: round(this.last.x),
      y: round(this.last.y),
    });

    if (!this.keepAliveTimer) {
      this.keepAliveTimer = setInterval(() => this.flush(), KEEPALIVE_MS);
    }
  }

  hide() {
    this.clearTimers();
    this.last = null;
    this.hideLocal();

    if (this.visible) {
      this.visible = false;
      this.context.pushEvent("pointer-hide", {});
    }
  }

  clearTimers() {
    clearTimeout(this.trailingTimer);
    clearInterval(this.keepAliveTimer);
    this.trailingTimer = null;
    this.keepAliveTimer = null;
  }
}

// Runs on the projected presentation and on attendees' devices. Draws the dot
// on top of the slide image matched by the element's `data-image-selector`.
//
// With a `data-pointer-control` attribute (the presenter window) it also lets
// the presenter steer the pointer with the mouse. The sender draws that dot
// itself, right under the mouse, and the server does not echo it back.
export class PointerOverlay {
  constructor(context) {
    this.context = context;
    this.el = context.el;
    this.dot = null;
    this.last = null;
    this.hideTimer = null;
    this.sender = null;
  }

  init() {
    this.dot = this.el.querySelector("[data-pointer-dot]");

    this.context.handleEvent("pointer", (data) => this.onPointer(data));

    this.onResize = () => this.render();
    window.addEventListener("resize", this.onResize);

    if (this.el.hasAttribute("data-pointer-control")) {
      this.sender = new PointerSender(this.context, {
        target: window,
        leaveTarget: document.documentElement,
        findImage: () => this.slideImage(),
        findHost: () => this.el,
        findCursorTarget: () => document.documentElement,
      });
      this.sender.init();
    }
  }

  destroy() {
    window.removeEventListener("resize", this.onResize);
    clearTimeout(this.hideTimer);
    if (this.sender) this.sender.destroy();
  }

  onPointer({ visible, x, y, slide_changed }) {
    if (!visible) {
      this.hide();
      if (slide_changed && this.sender) this.sender.reset();
      return;
    }

    this.last = { x, y };
    this.render();

    clearTimeout(this.hideTimer);
    this.hideTimer = setTimeout(() => this.hide(), HIDE_AFTER_MS);
  }

  hide() {
    clearTimeout(this.hideTimer);
    this.last = null;
    if (this.dot) this.dot.classList.add("hidden");
  }

  slideImage() {
    const selector = this.el.dataset.imageSelector;
    if (!selector) return null;

    return Array.from(document.querySelectorAll(selector)).find(
      (img) => img.getBoundingClientRect().width > 0
    );
  }

  render() {
    if (!this.dot) return;

    const img = this.last && this.slideImage();

    if (!img) {
      this.dot.classList.add("hidden");
      return;
    }

    const rect = slideRect(img);
    const host = this.el.getBoundingClientRect();

    this.dot.style.transition = "";
    this.dot.style.left = `${rect.left - host.left + this.last.x * rect.width}px`;
    this.dot.style.top = `${rect.top - host.top + this.last.y * rect.height}px`;
    this.dot.classList.remove("hidden");
  }
}
