import assert from "node:assert/strict";
import test from "node:test";

// The library only needs a mounting shell until it renders, and rendering
// waits for an animation frame that never comes here.
class Element {
  style = {};
  append() {}
  setAttribute() {}
  remove() {}
}

globalThis.HTMLElement = Element;
globalThis.CSS = { supports: () => true };
globalThis.document = { createElement: () => new Element() };
globalThis.ResizeObserver = class {
  observe() {}
  disconnect() {}
};
globalThis.requestAnimationFrame = () => 1;
globalThis.cancelAnimationFrame = () => {};

// Browsers leave out crypto.randomUUID on plain HTTP.
Object.defineProperty(globalThis, "crypto", { value: {}, configurable: true });

const { default: WordCloud } = await import("../js/word_cloud.mjs");

function mountHook(words, dataset = {}) {
  const el = new Element();
  el.dataset = { ...dataset, words: JSON.stringify(words) };

  const hook = { ...WordCloud, el };
  hook.mounted();

  const added = [];
  const add = hook.cloud.add;
  hook.cloud.add = (...args) => {
    added.push(args);
    return add(...args);
  };

  const update = (next) => {
    el.dataset.words = JSON.stringify(next);
    hook.updated();
  };

  return { hook, added, update };
}

const shown = (hook) => hook.cloud.getWords().map(({ id, name, count }) => ({ id, name, count }));

test("shows the words under the server's keys without generating ids", () => {
  const { hook, update } = mountHook([{ id: "elixir", name: "Elixir", count: 2 }]);

  update([
    { id: "elixir", name: "Elixir", count: 2 },
    { id: "phoenix", name: "Phoenix", count: 1 },
  ]);

  assert.deepEqual(shown(hook), [
    { id: "elixir", name: "Elixir", count: 2 },
    { id: "phoenix", name: "Phoenix", count: 1 },
  ]);
});

test("adds the new mentions of a word that was sent again", () => {
  const { hook, added, update } = mountHook([
    { id: "elixir", name: "Elixir", count: 1 },
    { id: "phoenix", name: "Phoenix", count: 1 },
  ]);

  update([
    { id: "elixir", name: "Elixir", count: 3 },
    { id: "phoenix", name: "Phoenix", count: 1 },
  ]);

  assert.deepEqual(added, [["Elixir", 2]]);
  assert.deepEqual(shown(hook)[0], { id: "elixir", name: "Elixir", count: 3 });
});

test("leaves out a hidden word and brings it back", () => {
  const words = [
    { id: "elixir", name: "Elixir", count: 1 },
    { id: "rude", name: "Rude", count: 4 },
  ];
  const { hook, added, update } = mountHook(words);

  update([words[0]]);
  assert.deepEqual(shown(hook), [words[0]]);

  update(words);
  assert.deepEqual(shown(hook), words);
  assert.deepEqual(added, []);
});

test("takes the text colour from the element", () => {
  const { hook } = mountHook([], { textColor: "white" });

  assert.equal(hook.cloud.getOptions().textColor, "white");
});

test("destroys the cloud with the element", () => {
  const { hook } = mountHook([{ id: "elixir", name: "Elixir", count: 1 }]);

  hook.destroyed();

  assert.deepEqual(hook.cloud.getWords(), []);
  assert.throws(() => hook.cloud.add("Elixir"));
});
