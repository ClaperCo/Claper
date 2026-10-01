import assert from "node:assert/strict";
import test from "node:test";

import DateTimeLocal from "../js/date_time_local.mjs";

function makeInput(value = "") {
  const attributes = new Map();
  if (value) attributes.set("value", value);

  return {
    value,
    setAttribute(name, val) {
      attributes.set(name, String(val));
    },
    removeAttribute(name) {
      attributes.delete(name);
    },
    getAttribute(name) {
      return attributes.has(name) ? attributes.get(name) : null;
    },
  };
}

function mountHook(utcValue = "2026-08-04T12:00:00") {
  const localTime = makeInput();
  const utcTime = makeInput(utcValue);
  const listeners = new Map();

  const el = {
    querySelector(selector) {
      return selector === "input[type=datetime-local]" ? localTime : utcTime;
    },
    addEventListener(type, listener) {
      listeners.set(type, listener);
    },
    removeEventListener(type) {
      listeners.delete(type);
    },
    dispatch(type, target) {
      listeners.get(type)?.({ target });
    },
  };

  const hook = { ...DateTimeLocal, el };
  hook.mounted();

  return { el, hook, localTime, utcTime };
}

function toLocalString(utcValue) {
  const date = new Date(`${utcValue}Z`);
  const pad = (part) => String(part).padStart(2, "0");
  return (
    `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}` +
    `T${pad(date.getHours())}:${pad(date.getMinutes())}`
  );
}

test("syncs the hidden UTC value when the datetime control only emits change", () => {
  const { el, localTime, utcTime } = mountHook();
  localTime.value = "2030-01-02T10:30";

  el.dispatch("change", localTime);

  assert.equal(utcTime.value, new Date(localTime.value).toISOString().slice(0, 19));
});

test("mirrors synced values into the value attribute so LiveView sees a DOM diff", () => {
  const { el, localTime, utcTime } = mountHook();

  assert.equal(localTime.getAttribute("value"), localTime.value);

  localTime.value = "2030-01-02T10:30";
  el.dispatch("input", localTime);

  assert.equal(utcTime.getAttribute("value"), utcTime.value);
  assert.equal(localTime.getAttribute("value"), "2030-01-02T10:30");
});

test("restores the local value after a patch outside the form wipes the input", () => {
  const utcValue = "2026-08-04T12:00:00";
  const { hook, localTime } = mountHook(utcValue);

  // Simulate morphdom patching against server HTML that has no value
  // attribute (e.g. re-render caused by an upload finishing): the input
  // property is reset and the attribute removed, then `updated` fires.
  localTime.value = "";
  localTime.removeAttribute("value");
  hook.updated();

  assert.equal(localTime.value, toLocalString(utcValue));
  assert.equal(localTime.getAttribute("value"), toLocalString(utcValue));
});

test("clears the local value and attribute when the UTC value is empty", () => {
  const { hook, localTime, utcTime } = mountHook();

  utcTime.value = "";
  hook.updated();

  assert.equal(localTime.value, "");
  assert.equal(localTime.getAttribute("value"), null);
});
