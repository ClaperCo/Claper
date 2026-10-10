import assert from "node:assert/strict";
import test from "node:test";

import RoomFeed from "../js/room_feed.mjs";

const SMOOTH_SCROLL_FRAMES = 4;

function makeChip() {
  const classes = new Set(["hidden"]);
  const count = { textContent: "" };

  return {
    count,
    classList: {
      add: (name) => classes.add(name),
      remove: (name) => classes.delete(name),
      contains: (name) => classes.has(name),
    },
    querySelector: () => count,
    addEventListener() {},
    removeEventListener() {},
  };
}

function mountFeed({ posts = 20, postHeight = 50, clientHeight = 500 } = {}) {
  const chip = makeChip();
  const listeners = new Map();
  const observers = [];

  globalThis.document = { querySelector: () => chip };
  globalThis.requestAnimationFrame = (callback) => callback();
  globalThis.ResizeObserver = class {
    constructor(callback) {
      this.callback = callback;
      observers.push(this);
    }
    observe() {}
    disconnect() {}
  };

  // As in a browser, a smooth scroll moves over several frames to a target
  // clamped when it starts, and scroll events arrive a frame later.
  const el = {
    dataset: { chip: "#new-messages-chip" },
    posts,
    extraHeight: 0,
    clientHeight,
    scrollTop: 0,
    animation: [],
    scrolled: false,
    get scrollHeight() {
      return this.posts * postHeight + this.extraHeight;
    },
    get maxScrollTop() {
      return Math.max(0, this.scrollHeight - this.clientHeight);
    },
    querySelectorAll() {
      return { length: this.posts };
    },
    scrollTo({ top, behavior }) {
      const target = Math.max(0, Math.min(top, this.maxScrollTop));

      if (behavior === "smooth") {
        const start = this.scrollTop;
        this.animation = Array.from(
          { length: SMOOTH_SCROLL_FRAMES },
          (_, i) => start + ((target - start) * (i + 1)) / SMOOTH_SCROLL_FRAMES,
        );
      } else {
        this.animation = [];
        this.moveTo(target);
      }
    },
    moveTo(scrollTop) {
      const clamped = Math.min(scrollTop, this.maxScrollTop);
      if (clamped !== this.scrollTop) this.scrolled = true;
      this.scrollTop = clamped;
    },
    tick() {
      if (this.animation.length > 0) this.moveTo(this.animation.shift());
      if (this.scrolled) {
        this.scrolled = false;
        listeners.get("scroll")?.();
      }
    },
    settle() {
      while (this.animation.length > 0 || this.scrolled) this.tick();
    },
    addEventListener(type, listener) {
      listeners.set(type, listener);
    },
    removeEventListener(type) {
      listeners.delete(type);
    },
    scrollByReader(scrollTop) {
      this.animation = [];
      this.scrolled = false;
      this.scrollTop = scrollTop;
      listeners.get("scroll")?.();
    },
    resize(clientHeight) {
      this.clientHeight = clientHeight;
      observers.forEach((observer) => observer.callback([]));
    },
  };

  const hook = { ...RoomFeed, el };
  hook.mounted();
  el.settle();

  const patch = (change) => {
    hook.beforeUpdate();
    change();
    hook.updated();
  };
  const distanceFromBottom = () =>
    el.scrollHeight - el.scrollTop - el.clientHeight;

  return { chip, el, patch, distanceFromBottom };
}

test("follows a new post when the reader is at the bottom", () => {
  const { chip, el, patch, distanceFromBottom } = mountFeed();

  patch(() => (el.posts += 1));
  el.settle();

  assert.equal(distanceFromBottom(), 0);
  assert.ok(chip.classList.contains("hidden"));
});

test("keeps following when posts arrive faster than the scroll animation", () => {
  const { chip, el, patch, distanceFromBottom } = mountFeed({
    postHeight: 120,
  });

  patch(() => (el.posts += 1));
  el.tick();
  patch(() => (el.posts += 1));
  el.settle();

  assert.equal(distanceFromBottom(), 0);
  assert.ok(chip.classList.contains("hidden"));
});

test("leaves a reader who scrolled up in place and counts the new post", () => {
  const { chip, el, patch } = mountFeed();
  el.scrollByReader(100);

  patch(() => (el.posts += 1));
  el.settle();

  assert.equal(el.scrollTop, 100);
  assert.ok(!chip.classList.contains("hidden"));
  assert.equal(chip.count.textContent, 1);
});

test("does not pull back a reader who scrolls up during the scroll animation", () => {
  const { chip, el, patch } = mountFeed({ postHeight: 120 });

  patch(() => (el.posts += 1));
  el.tick();
  const readerPosition = el.scrollTop - 200;
  el.scrollByReader(readerPosition);
  patch(() => (el.posts += 1));
  el.settle();

  assert.equal(el.scrollTop, readerPosition);
  assert.ok(!chip.classList.contains("hidden"));
  assert.equal(chip.count.textContent, 1);
});

test("does not move a reader near the bottom on a patch that adds nothing", () => {
  const { el, patch } = mountFeed();
  const readerPosition = el.maxScrollTop - 30;
  el.scrollByReader(readerPosition);

  patch(() => {});
  el.settle();

  assert.equal(el.scrollTop, readerPosition);
});

test("keeps the newest post in view when the feed gets shorter", () => {
  const { el, distanceFromBottom } = mountFeed();

  el.resize(300);
  el.settle();

  assert.equal(distanceFromBottom(), 0);
});

test("keeps following new posts after the feed got shorter", () => {
  const { chip, el, patch, distanceFromBottom } = mountFeed();
  el.clientHeight = 300;

  patch(() => (el.posts += 1));
  el.settle();

  assert.equal(distanceFromBottom(), 0);
  assert.ok(chip.classList.contains("hidden"));
});

test("shows a reply added to the newest post when the reader is at the bottom", () => {
  const { el, patch, distanceFromBottom } = mountFeed();

  patch(() => (el.extraHeight += 100));
  el.settle();

  assert.equal(distanceFromBottom(), 0);
});

test("keeps following new posts after the newest post grew", () => {
  const { chip, el, patch, distanceFromBottom } = mountFeed();

  patch(() => (el.extraHeight += 100));
  el.settle();
  patch(() => (el.posts += 1));
  el.settle();

  assert.equal(distanceFromBottom(), 0);
  assert.ok(chip.classList.contains("hidden"));
});

test("follows again once the feed grows to bring the reader back to the bottom", () => {
  const { chip, el, patch, distanceFromBottom } = mountFeed();
  el.scrollByReader(el.maxScrollTop - 100);

  el.resize(el.clientHeight + 80);
  patch(() => (el.posts += 1));
  el.settle();

  assert.equal(distanceFromBottom(), 0);
  assert.ok(chip.classList.contains("hidden"));
});

test("does not move a reader who scrolled up when the feed gets shorter", () => {
  const { el } = mountFeed();
  el.scrollByReader(100);

  el.resize(300);
  el.settle();

  assert.equal(el.scrollTop, 100);
});
