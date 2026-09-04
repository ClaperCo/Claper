// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket, Presence } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";
import Alpine from "alpinejs";
import moment from "moment-timezone";
import "moment/locale/de";
import "moment/locale/fr";
import "moment/locale/es";
import "moment/locale/nl";
import "moment/locale/it";
import "moment/locale/hu";
import "moment/locale/lv";
import QRCodeStyling from "qr-code-styling";
import { Presenter } from "./presenter";
import { Manager } from "./manager";
import { AudioCapture } from "./audio_capture";
import DateTimeLocal from "./date_time_local.mjs";
import Split from "split-grid";
import CustomHooks from "./hooks";
import "./admin-charts.js";
window.moment = moment;

// Get supported locales from backend configuration or fallback to default list
const supportedLocales = window.claperConfig?.supportedLocales || [
  "en",
  "fr",
  "de",
  "es",
  "nl",
  "it",
  "hu",
  "lv",
];

var locale =
  document.querySelector("html").getAttribute("lang") ||
  navigator.language.split("-")[0];

if (!supportedLocales.includes(locale)) {
  locale = "en";
}

window.moment.locale("en");
window.moment.locale(locale);
window.Alpine = Alpine;
Alpine.start();

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");
let Hooks = {};

Hooks.EmbeddedBanner = {
  mounted() {
    if (window !== window.parent) {
      this.el.classList.remove("hidden");
    }
  },
  updated() {
    if (window !== window.parent) {
      this.el.classList.remove("hidden");
    }
  },
};

Hooks.Split = {
  mounted() {
    const type = this.el.dataset.type;
    const id = this.el.id;
    const gutter = this.el.dataset.gutter;
    const forceLayout = this.el.classList.contains("grid-cols-[1fr]");
    const columnSlitValue =
      localStorage.getItem(`column-split-${id}`) || "1fr 10px 1fr";
    const rowSlitValue =
      localStorage.getItem(`row-split-${id}`) || "0.5fr 10px 1fr";

    if (type === "column") {
      this.columnSplit = Split({
        columnGutters: [
          {
            track: 1,
            element: this.el.querySelector(gutter),
          },
        ],
        onDragEnd: () => {
          const currentPosition = this.el.style["grid-template-columns"];
          localStorage.setItem(`column-split-${id}`, currentPosition);
        },
      });
      if (!forceLayout) {
        this.el.style["grid-template-columns"] = columnSlitValue;
      }
    } else {
      this.rowSplit = Split({
        rowGutters: [
          {
            track: 1,
            element: this.el.querySelector(gutter),
          },
        ],
        onDragEnd: () => {
          const value = this.el.style["grid-template-rows"];
          localStorage.setItem(`row-split-${id}`, value);
        },
      });
      if (!forceLayout) {
        this.el.style["grid-template-rows"] = rowSlitValue;
      }
    }
  },
  updated() {
    const id = this.el.id;
    const forceLayout = this.el.classList.contains("grid-cols-[1fr]");
    if (forceLayout) {
      return;
    }

    if (this.columnSplit) {
      this.columnSplit.destroy();
    }
    if (this.rowSplit) {
      this.rowSplit.destroy();
    }

    this.mounted();
  },
  destroyed() {
    if (this.columnSplit) {
      this.columnSplit.destroy();
    }
    if (this.rowSplit) {
      this.rowSplit.destroy();
    }
  },
};

Hooks.Scroll = {
  mounted() {
    if (this.el.dataset.postsNb > 4)
      window.scrollTo({
        top: document.querySelector(this.el.dataset.target).scrollHeight,
        behavior: "smooth",
      });
    this.handleEvent("scroll", () => {});
  },
  updated() {
    let t = document.querySelector(this.el.dataset.target);
    if (
      this.el.childElementCount > 4 &&
      window.scrollY + window.innerHeight >= t.offsetHeight - 300
    ) {
      window.scrollTo({ top: t.scrollHeight, behavior: "smooth" });
    }
  },
};

Hooks.RoomFeed = {
  mounted() {
    this.chip = document.querySelector(this.el.dataset.chip);
    this.unread = 0;
    this.atBottom = true;
    this.onScroll = () => {
      this.atBottom = this.distanceFromBottom() <= 48;
      if (this.atBottom) this.clearUnread();
    };
    this.onChipClick = () => this.scrollToBottom(true);
    this.onMessageSent = () => {
      this.sentMessage = true;
      this.scrollToBottom(true);
      clearTimeout(this.sentMessageTimeout);
      this.sentMessageTimeout = setTimeout(() => {
        this.sentMessage = false;
      }, 1000);
    };
    this.el.addEventListener("scroll", this.onScroll, { passive: true });
    this.el.addEventListener("room:message-sent", this.onMessageSent);
    this.chip?.addEventListener("click", this.onChipClick);
    requestAnimationFrame(() => this.scrollToBottom(true));
  },
  beforeUpdate() {
    this.wasAtBottom = this.distanceFromBottom() <= 48;
    this.previousPostCount = this.postCount();
  },
  updated() {
    const newPostCount = this.postCount();
    const hasNewPost = newPostCount > this.previousPostCount;

    if (hasNewPost && this.sentMessage) {
      clearTimeout(this.sentMessageTimeout);
      this.sentMessage = false;
      requestAnimationFrame(() => this.scrollToBottom(true));
    } else if (hasNewPost && this.wasAtBottom) {
      this.scrollToBottom();
    } else if (hasNewPost) {
      this.unread += newPostCount - this.previousPostCount;
      this.showUnread();
    }
  },
  destroyed() {
    this.el.removeEventListener("scroll", this.onScroll);
    this.el.removeEventListener("room:message-sent", this.onMessageSent);
    this.chip?.removeEventListener("click", this.onChipClick);
    clearTimeout(this.sentMessageTimeout);
  },
  postCount() {
    return this.el.querySelectorAll(":scope > [id^='posts-']").length;
  },
  distanceFromBottom() {
    return this.el.scrollHeight - this.el.scrollTop - this.el.clientHeight;
  },
  scrollToBottom(instant = false) {
    this.el.scrollTo({
      top: this.el.scrollHeight,
      behavior: instant ? "auto" : "smooth",
    });
    this.atBottom = true;
    this.clearUnread();
  },
  showUnread() {
    if (!this.chip) return;
    const count = this.chip.querySelector("[data-unread-count]");
    if (count) count.textContent = this.unread;
    this.chip.classList.remove("hidden");
  },
  clearUnread() {
    this.unread = 0;
    this.chip?.classList.add("hidden");
  },
};

Hooks.ScrollIntoDiv = {
  mounted() {
    let useParent = this.el.dataset.useParent === "true";
    this.scrollElement =
      this.el.dataset.useParent === "true" ? this.el.parentElement : this.el;
    this.checkIfAtBottom();
    this.scrollToBottom(true);
    this.handleEvent("scroll", () => this.scrollToBottom());
    this.scrollElement.addEventListener("scroll", () => this.checkIfAtBottom());
  },
  checkIfAtBottom() {
    this.isAtBottom =
      this.scrollElement.scrollHeight -
        this.scrollElement.scrollTop -
        this.scrollElement.clientHeight <=
      30;
  },
  scrollToBottom(force = false) {
    if (force || this.isAtBottom) {
      this.scrollElement.scrollTo({
        top: this.scrollElement.scrollHeight,
        behavior: "smooth",
      });
    }
  },
  updated() {
    this.scrollToBottom();
  },
  destroyed() {
    this.scrollElement.removeEventListener("scroll", () =>
      this.checkIfAtBottom(),
    );
  },
};

Hooks.NicknamePicker = {
  mounted() {
    this.storageKey = this.el.dataset.storageKey || "nickname";
    this.onClick = (event) => this.clicked(event);
    let currentNickname = this.currentNickname();
    if (currentNickname.length > 0) {
      this.pushEvent("set-nickname", { nickname: currentNickname });
    }

    this.el.addEventListener("click", this.onClick);
  },
  reconnected() {
    let currentNickname = this.currentNickname();
    if (currentNickname.length > 0) {
      this.pushEvent("set-nickname", { nickname: currentNickname });
    }
  },
  destroyed() {
    this.el.removeEventListener("click", this.onClick);
  },
  clicked(e) {
    let nickname = prompt(
      this.el.dataset.prompt,
      localStorage.getItem(this.storageKey) || "",
    );

    if (nickname) {
      nickname = nickname.trim();
      if (nickname.length < 2 || nickname.length > 20) {
        window.alert(this.el.dataset.invalid);
        return;
      }
      localStorage.setItem(this.storageKey, nickname);
      this.pushEvent("set-nickname", { nickname });
      this.js().exec(this.el.dataset.close);
    }
  },
  currentNickname() {
    const scopedNickname = localStorage.getItem(this.storageKey);
    if (scopedNickname !== null) return scopedNickname;

    const legacyNickname = (localStorage.getItem("nickname") || "").trim();
    localStorage.removeItem("nickname");
    if (legacyNickname.length < 2 || legacyNickname.length > 20) return "";

    localStorage.setItem(this.storageKey, legacyNickname);
    return legacyNickname;
  },
};

Hooks.EmptyNickname = {
  mounted() {
    this.onClick = () => {
      localStorage.removeItem(this.el.dataset.storageKey || "nickname");
      localStorage.removeItem("nickname");
    };
    this.el.addEventListener("click", this.onClick);
  },
  destroyed() {
    this.el.removeEventListener("click", this.onClick);
  },
};

Hooks.SearchableSelect = {
  mounted() {
    this.handleEvent("update_hidden_field", (payload) => {
      if (payload.id === this.el.id) {
        this.el.value = payload.value;
        // Trigger a change event to update the form
        const event = new Event('input', { bubbles: true });
        this.el.dispatchEvent(event);
      }
    });
  }
};

Hooks.PostForm = {
  mounted() {
    this.storageKey = this.el.dataset.storageKey;
    this.bindElements();
    this.restoreDraft();
    this.handleEvent("post-saved", () => {
      this.ta.value = "";
      localStorage.removeItem(this.storageKey);
      this.updateState();
      document
        .querySelector("#chat-feed")
        ?.dispatchEvent(new CustomEvent("room:message-sent"));
    });
  },
  updated() {
    this.bindElements();
    this.restoreDraft();
    this.updateState();
  },
  destroyed() {
    this.unbindElements();
  },
  bindElements() {
    const ta = this.el.querySelector("#postFormTA");
    const submit = this.el.querySelector("#submitBtn");
    if (this.ta === ta && this.submit === submit) return;

    this.unbindElements();
    this.ta = ta;
    this.submit = submit;
    if (!this.ta || !this.submit) return;

    this.onInput = () => {
      localStorage.setItem(this.storageKey, this.ta.value);
      this.updateState();
    };
    this.onKeyDown = (event) => {
      if (event.key === "Enter" && !event.shiftKey && this.valid()) {
        event.preventDefault();
        this.el.requestSubmit();
      }
    };
    this.ta.addEventListener("input", this.onInput);
    this.ta.addEventListener("keydown", this.onKeyDown);
  },
  unbindElements() {
    this.ta?.removeEventListener("input", this.onInput);
    this.ta?.removeEventListener("keydown", this.onKeyDown);
  },
  restoreDraft() {
    if (!this.ta || !this.storageKey || this.ta.value) return;
    this.ta.value = localStorage.getItem(this.storageKey) || "";
    this.updateState();
  },
  valid() {
    const length = this.ta?.value.trim().length || 0;
    return !this.ta?.disabled && length >= 2 && length <= 255;
  },
  updateState() {
    if (!this.ta || !this.submit) return;
    const valid = this.valid();
    this.submit.disabled = !valid;
    this.submit.classList.toggle("opacity-50", !valid);
    this.submit.classList.toggle("opacity-100", valid);
    this.ta.style.height = "auto";
    this.ta.style.height = `${Math.min(this.ta.scrollHeight, 64)}px`;
  },
};

Hooks.CalendarLocalDate = {
  mounted() {
    this.el.innerHTML = moment.utc(this.el.dataset.date).local().calendar();
  },
  updated() {
    this.el.innerHTML = moment.utc(this.el.dataset.date).local().calendar();
  },
};
Hooks.DateTimeLocal = DateTimeLocal;
Hooks.UpdateAttendees = {
  mounted() {
    this.handleEvent("update-attendees", ({ count }) => {
      this.el.textContent = count;

      const labelId = this.el.dataset.labelId;
      const label = labelId ? document.getElementById(labelId) : null;

      if (label) {
        label.textContent = count > 1 ? this.el.dataset.plural : this.el.dataset.singular;
      }
    });
  },
};
Hooks.Presenter = {
  mounted() {
    this.presenter = new Presenter(this);
    this.presenter.init();
  },
  updated() {
    this.presenter.update();
  },
};
Hooks.Manager = {
  mounted() {
    this.manager = new Manager(this);
    this.manager.init();
  },
  updated() {
    this.manager.update();
  },
};
const INTERACTION_DRAG_TYPE = "application/x-claper-interaction";
const isInteractionDrag = (e) =>
  e.dataTransfer && Array.from(e.dataTransfer.types).includes(INTERACTION_DRAG_TYPE);

Hooks.SlideSortable = {
  mounted() {
    this.from = null;

    this.el.addEventListener("dragstart", (e) => {
      const item = e.target.closest("[data-index]");
      if (!item) return;
      this.from = parseInt(item.dataset.index);
      e.dataTransfer.effectAllowed = "move";
      e.dataTransfer.setData("text/plain", item.dataset.index);
      setTimeout(() => item.classList.add("opacity-40"), 0);
    });

    this.el.addEventListener("dragover", (e) => {
      if (this.from === null && !isInteractionDrag(e)) return;
      e.preventDefault();
      e.dataTransfer.dropEffect = "move";
      const item = e.target.closest("[data-index]");
      this.clearDropTarget();
      if (item && parseInt(item.dataset.index) !== this.from) {
        item.classList.add("ring-2", "ring-primary-500");
      }
    });

    this.el.addEventListener("drop", (e) => {
      e.preventDefault();
      const item = e.target.closest("[data-index]");
      if (item && this.from !== null) {
        const to = parseInt(item.dataset.index);
        if (to !== this.from) {
          this.pushEvent("reorder-slides", { from: this.from, to: to });
        }
      } else if (item && isInteractionDrag(e)) {
        const data = JSON.parse(e.dataTransfer.getData(INTERACTION_DRAG_TYPE));
        const to = parseInt(item.dataset.index);
        if (to !== data.position) {
          this.pushEvent("move-interaction", { id: data.id, type: data.type, to: to });
        }
      }
      this.reset();
    });

    this.el.addEventListener("dragend", () => this.reset());
  },
  clearDropTarget() {
    this.el
      .querySelectorAll("[data-index]")
      .forEach((n) => n.classList.remove("ring-2", "ring-primary-500"));
  },
  reset() {
    this.from = null;
    this.clearDropTarget();
    this.el
      .querySelectorAll("[data-index]")
      .forEach((n) => n.classList.remove("opacity-40"));
  },
};
Hooks.InteractionDrag = {
  mounted() {
    this.lastInteractionListHeight = null;
    this.interactionListResizeObserver = new ResizeObserver(([entry]) => {
      const height = window.matchMedia("(min-width: 1024px)").matches
        ? Math.round(entry.contentRect.height)
        : 0;

      if (height === this.lastInteractionListHeight) return;
      this.lastInteractionListHeight = height;
      this.pushEventTo(this.el, "interaction-list-resized", { height });
    });
    this.interactionListResizeObserver.observe(this.el);

    this.el.addEventListener("dragstart", (e) => {
      const item = e.target.closest("[data-interaction-id]");
      if (!item) return;
      e.dataTransfer.effectAllowed = "move";
      e.dataTransfer.setData(
        INTERACTION_DRAG_TYPE,
        JSON.stringify({
          id: parseInt(item.dataset.interactionId),
          type: item.dataset.interactionType,
          position: parseInt(item.dataset.interactionPosition),
        }),
      );
      const rect = item.getBoundingClientRect();
      const ghost = item.cloneNode(true);
      ghost.style.width = `${rect.width}px`;
      ghost.style.position = "fixed";
      ghost.style.top = "-1000px";
      ghost.style.left = "-1000px";
      ghost.style.pointerEvents = "none";
      document.body.appendChild(ghost);
      e.dataTransfer.setDragImage(ghost, e.clientX - rect.left, e.clientY - rect.top);
      setTimeout(() => ghost.remove(), 0);
      setTimeout(() => item.classList.add("opacity-40"), 0);
    });

    this.el.addEventListener("dragend", () => {
      this.el
        .querySelectorAll("[data-interaction-id]")
        .forEach((n) => n.classList.remove("opacity-40"));
    });
  },
  destroyed() {
    this.interactionListResizeObserver.disconnect();
  },
};
Hooks.OpenPresenter = {
  open(e) {
    e.preventDefault();
    window.open(
      this.el.dataset.url,
      "newwindow",
      "width=" + window.screen.width + ",height=" + window.screen.height,
    );
  },
  mounted() {
    this.el.addEventListener("click", (e) => this.open(e));
  },
  updated() {
    this.el.removeEventListener("click", (e) => this.open(e));
    this.el.addEventListener("click", (e) => this.open(e));
  },
  destroyed() {
    this.el.removeEventListener("click", (e) => this.open(e));
  },
};

Hooks.AttendeeFocus = {
  mounted() {
    this.focusKey = this.el.dataset.focusKey;
    this.collapseKey = this.el.dataset.collapseKey;
    this.onClick = (event) => {
      if (event.target.closest("[data-focus-collapse]")) {
        localStorage.setItem(this.collapseKey, "collapsed");
        this.restoreCollapse();
        return;
      }

      if (event.target.closest("[data-focus-show]")) {
        localStorage.setItem(this.collapseKey, "expanded");
        this.restoreCollapse();
        return;
      }

      const fullscreenButton = event.target.closest("[data-focus-fullscreen]");
      if (fullscreenButton) {
        if (document.fullscreenElement) {
          document.exitFullscreen?.();
        } else if (this.el.classList.contains("focus-fallback-fullscreen")) {
          this.el.classList.remove("focus-fallback-fullscreen");
        } else {
          this.enterFullscreen();
        }
        return;
      }
    };
    this.onKeyDown = (event) => {
      if (event.key === "Escape") this.el.classList.remove("focus-fallback-fullscreen");
    };
    this.el.addEventListener("click", this.onClick);
    document.addEventListener("keydown", this.onKeyDown);
    this.restoreCollapse();
  },
  updated() {
    const nextKey = this.el.dataset.focusKey;
    if (this.focusKey !== nextKey) {
      const composer = document.querySelector("#postFormTA");
      const badge = this.el.querySelector("#new-interaction-badge");
      if (composer && document.activeElement === composer && badge) {
        badge.classList.remove("hidden");
        window.setTimeout(() => badge.classList.add("hidden"), 3000);
      }
      this.focusKey = nextKey;
    }
    this.restoreCollapse();
  },
  destroyed() {
    this.el.removeEventListener("click", this.onClick);
    document.removeEventListener("keydown", this.onKeyDown);
  },
  restoreCollapse() {
    const interactionMode = this.el.dataset.interactionMode === "true";
    const collapsed = localStorage.getItem(this.collapseKey) === "collapsed";
    this.el.classList.toggle("focus-collapsed", collapsed && !interactionMode);
  },
  enterFullscreen() {
    if (!this.el.requestFullscreen) {
      this.el.classList.add("focus-fallback-fullscreen");
      return;
    }

    this.el.requestFullscreen().catch(() => {
      this.el.classList.add("focus-fallback-fullscreen");
    });
  },
};

Hooks.AttendeeCaptions = {
  mounted() {
    this.collapseKey = this.el.dataset.collapseKey;
    this.onClick = (event) => {
      if (event.target.closest("[data-caption-collapse]")) {
        localStorage.setItem(this.collapseKey, "collapsed");
        this.restoreCollapse();
        return;
      }

      if (event.target.closest("[data-caption-show]")) {
        localStorage.setItem(this.collapseKey, "expanded");
        this.restoreCollapse();
      }
    };
    this.el.addEventListener("click", this.onClick);
    this.restoreCollapse();
  },
  updated() {
    this.restoreCollapse();
  },
  destroyed() {
    this.el.removeEventListener("click", this.onClick);
  },
  restoreCollapse() {
    const collapsed = localStorage.getItem(this.collapseKey) === "collapsed";
    this.el.classList.toggle("caption-collapsed", collapsed);
  },
};

// The chat panel is the flexible row of #attendee-room, so collapsing it has to
// hand that role to the focus slot. That is a sibling, which CSS cannot reach
// from the panel, so the class goes on the room and the stylesheet resizes both.
Hooks.AttendeeChat = {
  mounted() {
    this.collapseKey = this.el.dataset.collapseKey;
    this.room = this.el.closest("#attendee-room");
    this.onClick = (event) => {
      if (event.target.closest("[data-chat-collapse]")) {
        localStorage.setItem(this.collapseKey, "collapsed");
        this.restoreCollapse();
        return;
      }

      if (event.target.closest("[data-chat-show]")) {
        localStorage.setItem(this.collapseKey, "expanded");
        this.restoreCollapse();
      }
    };
    this.el.addEventListener("click", this.onClick);
    this.restoreCollapse();
  },
  updated() {
    this.restoreCollapse();
  },
  destroyed() {
    this.el.removeEventListener("click", this.onClick);
    // The presenter can hide the panel while an attendee has it collapsed. The
    // class lives on the room, which survives, so it has to be cleared here or
    // it would keep shrinking a panel that is no longer there.
    this.room?.classList.remove("chat-collapsed");
  },
  restoreCollapse() {
    const collapsed = localStorage.getItem(this.collapseKey) === "collapsed";
    this.room?.classList.toggle("chat-collapsed", collapsed);
  },
};

Hooks.RoomReactionFab = {
  mounted() {
    this.trigger = this.el.querySelector("[data-reaction-trigger]");
    this.picker = this.el.querySelector("[data-reaction-picker]");
    this.icon = this.el.querySelector("[data-reaction-icon]");
    this.reaction = "heart";
    this.updateIcon();

    this.onPointerDown = () => {
      this.longPressed = false;
      this.pressTimer = window.setTimeout(() => {
        this.longPressed = true;
        this.openPicker();
      }, 450);
    };
    this.onPointerUp = () => {
      window.clearTimeout(this.pressTimer);
      if (!this.longPressed) this.send(this.reaction);
    };
    this.onPointerCancel = () => window.clearTimeout(this.pressTimer);
    this.onContextMenu = (event) => event.preventDefault();
    this.onClick = (event) => {
      if (event.detail === 0) this.send(this.reaction);
    };
    this.onKeyDown = (event) => {
      if (["ArrowUp", "ArrowDown"].includes(event.key)) {
        event.preventDefault();
        this.openPicker();
        this.picker.querySelector("[data-reaction]")?.focus();
      } else if (event.key === "Escape") {
        this.closePicker();
      }
    };
    this.onPickerClick = (event) => {
      const button = event.target.closest("[data-reaction]");
      if (!button) return;
      this.send(button.dataset.reaction);
      this.closePicker();
      this.trigger.focus();
    };
    this.onPickerKeyDown = (event) => {
      if (event.key === "Escape") {
        this.closePicker();
        this.trigger.focus();
      }
    };

    this.trigger.addEventListener("pointerdown", this.onPointerDown);
    this.trigger.addEventListener("pointerup", this.onPointerUp);
    this.trigger.addEventListener("pointercancel", this.onPointerCancel);
    this.trigger.addEventListener("contextmenu", this.onContextMenu);
    this.trigger.addEventListener("click", this.onClick);
    this.trigger.addEventListener("keydown", this.onKeyDown);
    this.picker.addEventListener("click", this.onPickerClick);
    this.picker.addEventListener("keydown", this.onPickerKeyDown);
  },
  destroyed() {
    window.clearTimeout(this.pressTimer);
    this.trigger.removeEventListener("pointerdown", this.onPointerDown);
    this.trigger.removeEventListener("pointerup", this.onPointerUp);
    this.trigger.removeEventListener("pointercancel", this.onPointerCancel);
    this.trigger.removeEventListener("contextmenu", this.onContextMenu);
    this.trigger.removeEventListener("click", this.onClick);
    this.trigger.removeEventListener("keydown", this.onKeyDown);
    this.picker.removeEventListener("click", this.onPickerClick);
    this.picker.removeEventListener("keydown", this.onPickerKeyDown);
  },
  send(reaction) {
    this.reaction = reaction;
    this.updateIcon();
    this.pushEvent("global-react", { type: reaction });
  },
  updateIcon() {
    this.icon.src = `/images/icons/${this.reaction}.svg`;
  },
  openPicker() {
    this.picker.classList.remove("hidden");
    this.picker.classList.add("flex");
    this.trigger.setAttribute("aria-expanded", "true");
  },
  closePicker() {
    this.picker.classList.add("hidden");
    this.picker.classList.remove("flex");
    this.trigger.setAttribute("aria-expanded", "false");
  },
};

Hooks.GlobalReacts = {
  mounted() {
    this.svgCache = {};
    this.queue = [];
    this.activeReactions = new Map();
    this.sequence = 0;
    this.drainTimer = null;
    this.preloadSVGs();

    this.globalReactRef = this.handleEvent("global-react", (data) => {
      if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
      if (!this.svgTypes.includes(data.type)) return;

      this.queue.push(data.type);
      if (this.queue.length > 30) this.queue.shift();
      this.scheduleDrain(0);
    });
    this.resetGlobalReactRef = this.handleEvent("reset-global-react", () => this.reset());
  },

  destroyed() {
    this.removeHandleEvent?.(this.globalReactRef);
    this.removeHandleEvent?.(this.resetGlobalReactRef);
    this.reset();
  },

  get svgTypes() {
    return ["heart", "hundred", "clap", "raisehand"];
  },

  preloadSVGs() {
    this.svgTypes.forEach((type) => {
      fetch(`/images/icons/${type}.svg`)
        .then((response) => response.text())
        .then((svgContent) => {
          this.svgCache[type] = svgContent;
          this.scheduleDrain(0);
        })
        .catch((error) => {
          this.svgCache[type] = null;
          this.queue = this.queue.filter((queuedType) => queuedType !== type);
          console.error(`Error loading SVG for ${type}:`, error);
        });
    });
  },

  scheduleDrain(delay = 120) {
    if (this.drainTimer !== null || this.queue.length === 0) return;

    this.drainTimer = window.setTimeout(() => {
      this.drainTimer = null;
      this.drain();
    }, delay);
  },

  drain() {
    if (this.queue.length === 0) return;
    if (this.activeReactions.size >= 12) {
      this.scheduleDrain(100);
      return;
    }

    const type = this.queue[0];
    const svgContent = this.svgCache[type];

    if (svgContent === undefined) {
      this.scheduleDrain(100);
      return;
    }

    this.queue.shift();
    if (svgContent) this.play(svgContent);
    this.scheduleDrain();
  },

  play(svgContent) {
    const container = document.createElement("div");
    container.innerHTML = svgContent;
    const svgElement = container.firstElementChild;
    if (!svgElement) return;

    const animationClass =
      this.sequence++ % 2 === 0 ? "react-animation--short" : "react-animation--long";

    svgElement.classList.add(
      "react-animation",
      animationClass,
      "absolute",
      "transform",
      "opacity-0",
      ...(this.el.dataset.className || "h-12 w-12").split(" "),
    );
    svgElement.style.left = `${15 + Math.random() * 70}%`;
    svgElement.style.bottom = "1rem";

    let removalTimer;
    const cleanup = () => {
      window.clearTimeout(removalTimer);
      this.activeReactions.delete(svgElement);
      svgElement.remove();
      this.scheduleDrain(0);
    };

    svgElement.addEventListener("animationend", cleanup, { once: true });
    removalTimer = window.setTimeout(cleanup, 2300);
    this.activeReactions.set(svgElement, removalTimer);
    this.el.appendChild(svgElement);
  },

  reset() {
    this.queue = [];
    window.clearTimeout(this.drainTimer);
    this.drainTimer = null;
    this.activeReactions?.forEach((timer, element) => {
      window.clearTimeout(timer);
      element.remove();
    });
    this.activeReactions?.clear();
    this.el.innerHTML = "";
  },
};
Hooks.WelcomeEarly = {
  mounted() {
    if (localStorage.getItem("welcome-early") !== "false") {
      this.el.style.display = "block";
      this.el.children[0].addEventListener("click", (e) => {
        e.preventDefault();
        localStorage.setItem("welcome-early", "false");
        this.el.style.display = "none";
      });
    }
  },
  destroyed() {
    this.el.children[0].removeEventListener("click", (e) => {
      e.preventDefault();
      localStorage.setItem("welcome-early", "false");
      this.el.style.display = "none";
    });
  },
};
Hooks.ClickFeedback = {
  clicked(e) {
    this.el.className = "animate__animated animate__rubberBand animate__faster";
    setTimeout(() => {
      this.el.className = "";
    }, 500);
  },
  mounted() {
    this.el.addEventListener("click", (e) => this.clicked(e));
  },
  destroyed() {
    this.el.removeEventListener("click", (e) => this.clicked(e));
  },
};
Hooks.QRCode = {
  draw() {
    var url = this.el.dataset.code
      ? window.location.protocol +
        "//" +
        window.location.host +
        "/e/" +
        this.el.dataset.code
      : window.location.href;
    var size = this.el.dataset.dynamic
      ? document.documentElement.clientWidth * 0.25
      : parseInt(this.el.dataset.size || "240", 10);

    if (this.el.dataset.dynamic) {
      this.el.style.width = document.documentElement.clientWidth * 0.27 + "px";
      this.el.style.height = document.documentElement.clientWidth * 0.27 + "px";
    }

    if (this.qrCode == null) {
      this.qrCode = new QRCodeStyling({
        width: size,
        height: size,
        margin: 0,
        data: url,
        cornersSquareOptions: {
          type: "square",
        },
        dotsOptions: {
          type: "square",
          color: "#000000",
        },
        backgroundOptions: {
          color: "#ffffff",
        },
        imageOptions: {
          crossOrigin: "anonymous",
          imageSize: 0.6,
          margin: 10,
        },
      });
      this.qrCode.append(this.el);
    } else {
      this.qrCode.update({
        width: size,
        height: size,
      });
    }
  },
  mounted() {
    window.addEventListener("resize", this.draw.bind(this));
    this.draw();
    if (this.el.dataset.getUrl) {
      setTimeout(() => {
        var dataURL = this.qrCode._canvas.toDataURL();
        document.getElementById("qr-url").value = dataURL;
      }, 500);
    }
  },
  updated() {},
  destroyed() {},
};

Hooks.TicketTilt = {
  // Writes tilt/glare values as CSS vars on <html> rather than inline
  // styles on the ticket: the countdown patches this subtree every
  // second and morphdom would wipe inline styles mid-animation.
  mounted() {
    if (
      !window.matchMedia("(pointer: fine)").matches ||
      window.matchMedia("(prefers-reduced-motion: reduce)").matches
    ) {
      return;
    }

    this.root = document.documentElement;
    this.frame = null;

    this.onMove = (e) => {
      this.lastEvent = e;
      if (this.frame) return;
      this.frame = requestAnimationFrame(() => {
        this.frame = null;
        const r = this.el.getBoundingClientRect();
        const x = this.lastEvent.clientX - r.left;
        const y = this.lastEvent.clientY - r.top;
        const px = x / r.width - 0.5;
        const py = y / r.height - 0.5;
        this.root.style.setProperty("--tilt-ry", (px * 10).toFixed(2) + "deg");
        this.root.style.setProperty("--tilt-rx", (py * -8).toFixed(2) + "deg");
        this.root.style.setProperty("--glare-x", x.toFixed(0) + "px");
        this.root.style.setProperty("--glare-y", y.toFixed(0) + "px");
        this.root.style.setProperty("--glare-o", "1");
      });
    };

    this.onLeave = () => {
      if (this.frame) {
        cancelAnimationFrame(this.frame);
        this.frame = null;
      }
      this.root.style.setProperty("--tilt-rx", "0deg");
      this.root.style.setProperty("--tilt-ry", "0deg");
      this.root.style.setProperty("--glare-o", "0");
    };

    this.el.addEventListener("mousemove", this.onMove);
    this.el.addEventListener("mouseleave", this.onLeave);
  },
  destroyed() {
    if (!this.onMove) return;
    this.el.removeEventListener("mousemove", this.onMove);
    this.el.removeEventListener("mouseleave", this.onLeave);
    if (this.frame) cancelAnimationFrame(this.frame);
    ["--tilt-rx", "--tilt-ry", "--glare-x", "--glare-y", "--glare-o"].forEach(
      (p) => document.documentElement.style.removeProperty(p),
    );
  },
};

Hooks.Dropdown = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      this.el.classList.toggle("hidden");
    });
  },
};

Hooks.AdminChart = {
  mounted() {
    const chartType = this.el.dataset.chartType;
    const canvasId = this.el.querySelector('canvas').id;
    const data = JSON.parse(this.el.dataset.chartData);
    
    if (chartType === 'users') {
      window.AdminCharts.createUsersChart(canvasId, data);
    } else if (chartType === 'events') {
      window.AdminCharts.createEventsChart(canvasId, data);
    }
    
    this.handleEvent("update_chart", (newData) => {
      window.AdminCharts.updateChart(canvasId, newData);
    });
  },
  
  updated() {
    const chartType = this.el.dataset.chartType;
    const canvasId = this.el.querySelector('canvas').id;
    const data = JSON.parse(this.el.dataset.chartData);
    
    if (chartType === 'users') {
      window.AdminCharts.createUsersChart(canvasId, data);
    } else if (chartType === 'events') {
      window.AdminCharts.createEventsChart(canvasId, data);
    }
  },
  
  destroyed() {
    const canvasId = this.el.querySelector('canvas').id;
    window.AdminCharts.destroyChart(canvasId);
  }
};

Hooks.CSVDownloader = {
  mounted() {
    this.handleEvent("download_csv", ({ filename, content }) => {
      const blob = new Blob([content], { type: 'text/csv' });
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = filename;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      window.URL.revokeObjectURL(url);
    });
  }
};

Hooks.TranscriptionCapture = {
  mounted() {
    this.audioCapture = null;
    this.handleEvent("transcription-state", ({ enabled }) => {
      if (enabled) {
        this.startCapture();
      } else {
        this.stopCapture();
      }
    });
  },
  startCapture() {
    if (this.audioCapture) return;
    const eventUuid = this.el.dataset.eventUuid;
    const audioToken = this.el.dataset.audioToken;
    const savedDeviceId = localStorage.getItem(`mic-${eventUuid}`);
    this.audioCapture = new AudioCapture(eventUuid, audioToken);
    this.audioCapture.start(savedDeviceId || null);
  },
  stopCapture() {
    if (this.audioCapture) {
      this.audioCapture.stop();
      this.audioCapture = null;
    }
  },
  destroyed() {
    this.stopCapture();
  },
};

Hooks.MicSelector = {
  mounted() {
    if (!navigator.mediaDevices) {
      console.warn("MicSelector: mediaDevices unavailable (requires HTTPS)");
      return;
    }
    this.populateDevices();
    navigator.mediaDevices.addEventListener("devicechange", () =>
      this.populateDevices(),
    );
  },
  async populateDevices() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      stream.getTracks().forEach((track) => track.stop());
    } catch (e) {
      // Permission denied - populate with what we can
    }
    const devices = await navigator.mediaDevices.enumerateDevices();
    const audioInputs = devices.filter((d) => d.kind === "audioinput");
    const select = this.el;
    select.innerHTML = "";
    audioInputs.forEach((device) => {
      const opt = document.createElement("option");
      opt.value = device.deviceId;
      opt.textContent =
        device.label || `Microphone ${device.deviceId.slice(0, 8)}`;
      select.appendChild(opt);
    });
    const saved = localStorage.getItem(
      `mic-${this.el.dataset.eventUuid}`,
    );
    if (saved) select.value = saved;
    select.addEventListener("change", () => {
      localStorage.setItem(
        `mic-${this.el.dataset.eventUuid}`,
        select.value,
      );
    });
  },
};

// Merge our custom hooks with the existing hooks
Object.assign(Hooks, CustomHooks);

let liveSocket = new LiveSocket("/live", Socket, {
  params: {
    _csrf_token: csrfToken,
    tz: Intl.DateTimeFormat().resolvedOptions().timeZone,
    host: window.location.host,
  },
  hooks: Hooks,
  dom: {
    onBeforeElUpdated(from, to) {
      if (from._x_dataStack) {
        window.Alpine.clone(from, to);
        window.Alpine.initTree(to);
      }
    },
  },
});

// Show progress bar on live navigation and form submits
let topBarScheduled = undefined;
topbar.config({ barColors: { 0: "#fff" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (info) => {
  if (!topBarScheduled) {
    topBarScheduled = setTimeout(() => topbar.show(), 500);
  }
});
window.addEventListener("phx:page-loading-stop", (info) => {
  clearTimeout(topBarScheduled);
  topBarScheduled = undefined;
  topbar.hide();
});

const onlineUserTemplate = function (user) {
  return `
    <div id="online-user">
      <strong class="text-secondary">aaa</strong>
    </div>
  `;
};

let presences = {};
liveSocket.on("presence_state", (state) => {
  presences = Presence.syncState(presences, state);
});

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;
