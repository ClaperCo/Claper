const DateTimeLocal = {
  mounted() {
    this.localTime = this.el.querySelector("input[type=datetime-local]");
    this.utcTime = this.el.querySelector("input[type=hidden]");
    this.syncLocalTime();

    this.handleInput = ({ target }) => {
      if (target === this.localTime) this.syncUtcTime();
    };
    this.el.addEventListener("input", this.handleInput);
    this.el.addEventListener("change", this.handleInput);
  },
  updated() {
    this.localTime = this.el.querySelector("input[type=datetime-local]");
    this.utcTime = this.el.querySelector("input[type=hidden]");
    this.syncLocalTime();
  },
  syncLocalTime() {
    if (!this.utcTime.value) {
      this.setValue(this.localTime, "");
      return;
    }

    const value = this.utcTime.value.replace(" ", "T").replace(/Z$/, "");
    const date = new Date(`${value}Z`);

    if (!Number.isNaN(date.getTime())) {
      const pad = (part) => String(part).padStart(2, "0");
      this.setValue(
        this.localTime,
        `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}` +
          `T${pad(date.getHours())}:${pad(date.getMinutes())}`,
      );
    }
  },
  syncUtcTime() {
    if (!this.localTime.value) {
      this.setValue(this.utcTime, "");
      return;
    }

    const date = new Date(this.localTime.value);

    if (!Number.isNaN(date.getTime())) {
      this.setValue(this.utcTime, date.toISOString().slice(0, 19));
      this.setValue(this.localTime, this.localTime.value);
    }
  },

  setValue(input, value) {
    input.value = value;
    if (value) {
      input.setAttribute("value", value);
    } else {
      input.removeAttribute("value");
    }
  },
  destroyed() {
    this.el.removeEventListener("input", this.handleInput);
    this.el.removeEventListener("change", this.handleInput);
  },
};

export default DateTimeLocal;
